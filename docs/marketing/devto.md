---
title: Why the macOS play/pause key goes to the wrong app, and how I fixed it
published: false
tags: macos, swift, opensource, showdev
canonical_url: https://smartpause.yasinozmeen.me
cover_image: https://smartpause.yasinozmeen.me/og.png
---

Press play/pause on a Mac while a YouTube tab is playing. Half the time the video keeps going and Apple Music opens instead. I lived with this for years, then spent a few weeks fixing it. The fix is a small open-source menu bar app called [SmartPause](https://github.com/yasinozmeen/smartpause). This post is about why the bug exists and what I learned building the fix.

## Why the key goes to the wrong app

macOS does not send the media key to the app that is making sound. It sends it to the app it considers "Now Playing". That is a single slot, filled by whichever app last registered itself through the MediaRemote framework. Browsers register when a tab starts playing, but they also drop out, get replaced by another app, or keep the slot long after the tab was closed. When the slot is empty, macOS falls back to Apple Music. That is the "Music opens by itself" moment.

So the key is routed by memory, not by what you hear. The fix is obvious once you say it out loud: route it by what you hear.

## Finding out who is making sound

Since macOS 14.2, Core Audio exposes a public process list with a flag that says whether a process is currently outputting audio (`kAudioProcessPropertyIsRunningOutput`). No microphone permission, no screen recording, and it costs nothing while idle because you only ask when a key is pressed.

The catch: Core Audio keeps reporting an app as "outputting" for a few seconds after it pauses. Spotify in particular stays on for a while. So the process list is a hint, not the truth. SmartPause asks the app itself through its scripting interface (`player state` for Spotify and Music, a small JavaScript snippet for browsers) and trusts that answer.

## Catching the key

Media keys arrive as `NSSystemDefined` events with subtype 8. A `CGEventTap` on the session sees them before macOS does, and returning `nil` from the callback swallows the key. That needs the Accessibility permission, which is the only permission the app asks for.

Two things bit me here.

First, ad-hoc code signatures change on every build, and macOS silently drops the Accessibility grant when the signature changes. During development the app would just stop hearing keys with no error. Sign with a stable identity or expect to re-grant.

Second, and this one took a day to find: the event tap callback ran on the main thread, and one of the AppleScript calls blocked. A stalled browser tab can hold an Apple Event for 120 seconds. macOS gives an event tap about a second to return; if it does not, the tap is disabled and every media key goes back to the system. The app looked alive but did nothing. The tap now runs on its own thread with its own run loop, decisions go to a serial queue, and every AppleScript call has a 4 second cap.

## Two apps playing

The interesting product question was what a single key should do when two apps are playing. I settled on: a single press switches (the playing app pauses, the other one resumes and moves to the top of the list), a double press plays or pauses the selected one. A small widget at the top right shows what happened and what the next press will do. It slides in from the screen edge and moves out of the way of macOS notification banners.

When nothing is playing and nothing was paused recently, the key is handed back to macOS. macOS then does its usual thing and starts whatever it remembers. SmartPause cannot predict that (the API for it is private and locked down since 15.4), but it can look again 0.7 seconds later, see which app started, and show it in the widget. The next press then controls that app.

## What it is

Swift, AppKit plus SwiftUI, MIT, about 2,300 lines. No analytics, no accounts, no network access. Homebrew cask or a zip. Not notarized yet; that is what the Buy Me a Coffee link is for.

```
brew install --cask yasinozmeen/smartpause/smartpause
```

Site: https://smartpause.yasinozmeen.me
Source: https://github.com/yasinozmeen/smartpause

Arc and VLC adapters exist but are untested because I do not use them. If you do, a log from `~/Library/Logs/SmartPause.log` in an issue would help a lot.
