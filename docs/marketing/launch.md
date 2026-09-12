# Launch kit

Site: https://smartpause.yasinozmeen.me · Repo: https://github.com/yasinozmeen/smartpause · GIF: `docs/marketing/demo.gif` · Stills: `1-hero.png … 5-music.png`

Done: GitHub description/topics set, awesome-mac PR open (jaywcjlove/awesome-mac#2837).
To do by hand: GitHub Settings › Social preview → upload `docs/marketing/1-hero.png`.

Order: HN + r/macapps same day (Tue–Thu, 14:00 TR) → X/Mastodon → r/MacOS next day → directories over the following week.

---

## Show HN

Title:
```
Show HN: SmartPause – macOS play/pause key that pauses what's actually playing
```

First comment:
```
I built this because play/pause on my Mac opened Apple Music instead of pausing YouTube. macOS sends the media key to whatever it last remembers as "Now Playing", often the wrong app.

SmartPause catches the key (CGEventTap), asks Core Audio which process is outputting sound right now (public API since 14.2, no mic permission, zero CPU idle) and sends the command there via AppleScript. Two apps playing: single press switches, double press plays/pauses the selected one; a small widget shows what happened.

Lessons: Core Audio keeps reporting a paused app as "outputting" for a while, so adapters ask the app itself. A stalled browser tab can block an Apple Event for 120 s, which made macOS disable the event tap; the tap now runs on its own thread with a 4 s cap per command. Ad-hoc signatures change every build and silently drop the Accessibility permission.

Swift, MIT, Homebrew cask. Site: https://smartpause.yasinozmeen.me. Arc and VLC adapters are untested (I don't have them); logs welcome.
```

## Reddit (r/macapps, then r/MacOS, r/spotify, r/opensource)

Title:
```
Free menu bar app that stops the play/pause key from opening Apple Music
```

Body:
```
Hit play/pause to stop YouTube and Apple Music opens instead? macOS sends the key to whatever it last remembers, not to what's making sound.

SmartPause sends it to the app actually playing. Spotify, Apple Music, VLC, Chrome, Brave, Safari. Two apps playing: one press switches, double press plays/pauses, a small widget shows what it did.

Free, open source, no analytics, Accessibility permission only.
brew install --cask yasinozmeen/smartpause/smartpause

https://smartpause.yasinozmeen.me · https://github.com/yasinozmeen/smartpause
```

## X / Mastodon

```
Play/pause on your Mac opens Apple Music instead of pausing YouTube? macOS sends the key to what it *remembers*, not to what's playing.

SmartPause pauses the app actually making sound. Free, open source, Swift.
https://smartpause.yasinozmeen.me
```
Attach the GIF. Reply thread: 1) how it works (Core Audio + event tap), 2) the 120 s Apple Event story, 3) "which app next?"

## Product Hunt

Tagline:
```
The play/pause key, finally aimed at what's playing
```
Description:
```
macOS routes the media key to whatever it last remembers, so YouTube keeps playing and Apple Music opens. SmartPause finds the app actually outputting audio and pauses that. Two apps playing? One press switches, double press plays/pauses. Free, open source, menu bar only.
```
Website: https://smartpause.yasinozmeen.me. Gallery: demo.gif, then 2-widget, 3-panel, 4-onboarding, 5-music. Launch Tuesday 00:01 PT.

## Directories (one-time)

| Where | Text |
|---|---|
| AlternativeTo | Alternative to noTunes, BeardedSpice. Use the Reddit body. |
| MacUpdate | Upload zip + icon + 3 stills. Use the PH description. |
| Indie Hackers / Dev.to | Title: "Why the macOS play/pause key goes to the wrong app, and how I fixed it". Body: the HN comment, expanded. |
| homebrew-cask (main) | Later, after 30+ stars and a second release. |

## Buy Me a Coffee

Page: https://buymeacoffee.com/yasinozmeen. Mention it only when someone asks how to support; never in the launch posts themselves.

## Replies

- **noTunes?** Only blocks Music from launching. SmartPause routes the key and handles two sources.
- **BeardedSpice?** Unmaintained since 2019, needs browser extensions. SmartPause needs none.
- **Screen Recording / mic?** No. Accessibility only.
- **Notarized?** Not yet, ad-hoc signed. Right-click › Open once.
- **Arc / VLC?** Adapters exist, untested. Paste `~/Library/Logs/SmartPause.log` in an issue.
