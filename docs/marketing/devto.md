---
title: The macOS play/pause key goes to the wrong app, so I built a router for it
published: false
tags: macos, swift, opensource, showdev
canonical_url: https://smartpause.yasinozmeen.me
cover_image: https://smartpause.yasinozmeen.me/og.png
---

A YouTube tab is playing in Brave. I press play/pause on the keyboard. The video keeps going and Apple Music opens on top of everything, playing a song I did not ask for.

I did this for years. Close Music, click the tab, press space. Then one evening I opened Console to find out why, and ended up writing SmartPause, a small menu bar app that sends the key to the app that is actually making sound. Source is on GitHub: [github.com/yasinozmeen/smartpause](https://github.com/yasinozmeen/smartpause).

This is what I learned about media keys on macOS, and the four things that cost me the most time.

## Where the key actually goes

macOS keeps one "Now Playing" slot. Whichever app last registered with the MediaRemote framework owns it, and the play/pause key goes there. Browsers register when a tab starts playing, then lose the slot to another app, or keep it after the tab is gone. From the outside you cannot tell which.

When the slot is empty, macOS falls back to Apple Music. That is the "Music opens by itself" moment. The key is routed by memory, not by sound.

## Ask Core Audio instead

Since macOS 14.2 Core Audio exposes the list of audio processes as public API, with a property that says whether each one is outputting right now. No microphone permission, no screen recording, and nothing runs until you press a key.

```swift
static func runningOutputProcesses() -> [AudioProcess] {
    var a = addr(kAudioHardwarePropertyProcessObjectList)
    var size: UInt32 = 0
    let sys = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.compactMap { id in
        guard (get(id, kAudioProcessPropertyIsRunningOutput, UInt32(0)) ?? 0) != 0,
              let pid = get(id, kAudioProcessPropertyPID, Int32(0)) else { return nil }
        // bundle id, responsible pid, name ...
    }
}
```

The whole call takes about 14 ms. That is the core of the app. Everything below is the part that made it actually work.

## Gotcha #1: Core Audio keeps saying "playing" after you pause

Pause Spotify and `kAudioProcessPropertyIsRunningOutput` stays true for a few seconds, sometimes longer. The audio unit is still open; it just outputs silence. If you trust that flag you will "pause" an app that is already paused, which for Spotify's `playpause` command means resuming it.

So the process list is a hint. The app itself has the answer, and every app exposes it differently:

```applescript
tell application "Spotify" to (player state is playing) as string
```

Browsers have no player state, but they do have the DOM:

```applescript
tell application "Brave Browser"
  tell active tab of front window
    execute javascript "[...document.querySelectorAll('video,audio')].some(e=>!e.paused)"
  end tell
end tell
```

That needs "Allow JavaScript from Apple Events" enabled in the browser's Develop menu, once. SmartPause detects when it is off and shows how to turn it on instead of failing silently.

I also stopped using toggle commands entirely. `playpause` is a coin flip when your state is wrong; `play` and `pause` are not.

## Gotcha #2: the process making sound is not the app

Core Audio reports the process that opened the audio device. For Brave that is a GPU helper, for Safari it is `WebKit.GPU`, and neither has a bundle ID you can script. The helper's parent is not the app either.

There is a libSystem function that TCC itself uses to answer "which app is responsible for this pid":

```swift
private typealias Fn = @convention(c) (pid_t) -> pid_t
let sym = dlsym(dlopen(nil, RTLD_NOW), "responsibility_get_pid_responsible_for_pid")
let responsible = unsafeBitCast(sym, to: Fn.self)(helperPID)
```

It is undocumented, so it lives in one file behind a fallback that returns the original pid if the symbol is missing.

## Catching the key

Media keys arrive as `NX_SYSDEFINED` events (type 14) with subtype 8. A session-level `CGEventTap` sees them before macOS does; returning `nil` from the callback swallows the key. This needs the Accessibility permission, the only one the app asks for.

```swift
guard ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
let keyCode = Int((ns.data1 & 0xFFFF0000) >> 16)   // 16 = play/pause
let keyDown = ((ns.data1 & 0xFF00) >> 8) == 0x0A
guard (16...20).contains(keyCode) else { return Unmanaged.passUnretained(event) }
queue.async {
    if !handler(keyCode) { Self.reinject(keyCode: keyCode) }
}
return nil
```

If the app decides not to handle the key (nothing is playing, or the app has no adapter) it posts the same event back into the HID stream with a marker in `eventSourceUserData`, and the tap lets marked events through. Nothing is ever lost: worst case the key does exactly what it did before SmartPause existed.

## Gotcha #3: a slow callback kills your tap, silently

The first version made the AppleScript calls on the main thread, inside the tap callback. It worked for a week. Then one day media keys stopped doing anything at all, no crash, no log.

A browser tab that is busy (or a browser that is showing a modal dialog) can hold an Apple Event for 120 seconds. macOS gives an event tap roughly a second to return. Miss that and you get `kCGEventTapDisabledByTimeout` and every key goes back to the system until you re-enable the tap.

Three changes fixed it for good:

1. The tap runs on its own thread with its own `CFRunLoop`, so nothing on the main thread can stall it.
2. The callback only enqueues; decisions happen on a serial `DispatchQueue`.
3. Every AppleScript call is wrapped in a timeout.

```swift
let wrapped = "with timeout of 4 seconds\n\(source)\nend timeout"
let result = NSAppleScript(source: wrapped)?.executeAndReturnError(&err)
```

The tap also re-enables itself when it sees the disabled-by-timeout event, as a last line of defence.

## Gotcha #4: ad-hoc signatures lose the Accessibility grant

Every `swift build` produces a new ad-hoc signature, and macOS quietly ties the Accessibility grant to the old one. The app shows as enabled in System Settings, `AXIsProcessTrusted()` returns true, and the tap gets nothing. Toggle the checkbox off and on and it works again.

I lost an afternoon to this before finding it. If you ship without a Developer ID (I do, for now), tell users what to do when keys stop working after an update.

## What one key should do with two apps

The part I did not expect to spend time on. If Spotify and a YouTube tab are both playing, what should a single play/pause do?

What I settled on: a single press switches. The playing app pauses, the other one resumes and moves to the top of the list. A double press plays or pauses the selected app. A small widget at the top right shows what happened and what the next press will do, slides in from the screen edge, and moves down if a macOS notification banner is in the way.

When nothing is playing and nothing was paused recently, the key goes back to macOS, which starts whatever it remembers. Predicting that would need the private MediaRemote API, which is locked down since 15.4. Instead the app looks again 0.7 seconds later, sees which app started outputting, shows it in the widget and remembers it. The next press controls that app.

## Limitations

- Arc and VLC adapters exist but are untested. I do not use either.
- Not notarized. Right-click, Open on first launch. The Buy Me a Coffee link on the repo is for the Developer ID fee.
- Browsers need the "JavaScript from Apple Events" setting. Without it the key is handed back to macOS for that browser, so nothing breaks, it just is not smarter.
- Electron apps that play audio without the Media Session API are seen as "unknown" and passed through.

## Try it

macOS 14.2 or newer, Apple Silicon and Intel, about 2,300 lines of Swift, MIT, no analytics.

```
brew install --cask yasinozmeen/smartpause/smartpause
```

Site: [smartpause.yasinozmeen.me](https://smartpause.yasinozmeen.me). Source: [github.com/yasinozmeen/smartpause](https://github.com/yasinozmeen/smartpause).

If you have Arc or VLC and try it, `~/Library/Logs/SmartPause.log` in an issue is the most useful thing you can send me. Happy to answer questions about any of the above in the comments.
