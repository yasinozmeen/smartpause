# Launch kit

Site: https://smartpause.yasinozmeen.me · Repo: https://github.com/yasinozmeen/smartpause · GIF: `docs/marketing/demo.gif` · Stills: `1-hero.png … 5-music.png`

Done: GitHub description/topics set, awesome-mac PR open (jaywcjlove/awesome-mac#2837), X post (TR, 2026-09-12), Product Hunt scheduled Tue 2026-09-15 00:01 PT: https://www.producthunt.com/products/smartpause-2 (after launch: add PH badge to README).
To do by hand: GitHub Settings › Social preview → upload `docs/marketing/1-hero.png`.

Order (revised 2026-09-12): X/Mastodon + Product Hunt + directories now. Gated, retry later:
- HN: new accounts cannot post Show HN; build karma, retry in a few weeks.
- r/macapps: account 7+ days and 10 comment karma in the sub → after 19 Sep.
- r/MacOS: posted 2026-09-12, removed by GitHub-Guard cached score, approved by mods after modmail: https://www.reddit.com/r/MacOS/s/WY0fxXevZD

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

## Reddit r/macapps

Rules (checked 2026-09-12): 10 local karma first (comment on a few threads), flair **Free**, `[OS]` prefix, once per 30 days, official links only. Top posts use the Problem / Comparison / Pricing template and end with a question. Paste as plain text: Reddit's editor shows markdown asterisks literally; bold the section names with the B button if wanted. Avoid "I built…" in the title (r/MacOS mocks it).

Title:
```
[OS] SmartPause: the play/pause key finally pauses what's actually playing (free noTunes/BeardedSpice alternative)
```

Body:
```
Problem

Press play/pause to stop a YouTube tab and Apple Music opens instead. macOS sends the media key to whatever it last remembers as "Now Playing", not to the app making sound. With two apps open it gets worse: the key lands on the wrong one and you go hunting for the tab.

SmartPause is a menu bar app that asks Core Audio which app is outputting sound right now and sends the key there. Two apps playing: one press switches (the playing one pauses, the other starts), double press plays/pauses the selected one. A small widget at the top right shows what happened and what the next press will do. If nothing is playing, the key goes back to macOS and the widget shows which app macOS started.

Works with Spotify, Apple Music, VLC, Chrome, Brave, Safari. Arc and VLC adapters exist but are untested (I don't have them); logs welcome.

Comparison

noTunes only blocks Apple Music from launching. SmartPause routes the key to the right app and handles two sources.
BeardedSpice needs browser extensions and hasn't been updated since 2019. SmartPause needs none.
Nothing else I found handles the "two apps playing" case.

Pricing

Free, open source (MIT), no analytics, no account. One permission: Accessibility, to see the media keys. No microphone, no screen recording.

Links

Site: https://smartpause.yasinozmeen.me
Source: https://github.com/yasinozmeen/smartpause
Install: brew install --cask yasinozmeen/smartpause/smartpause

Notes

Not notarized yet (no Apple Developer account); right-click, then Open on first launch. macOS 14.2+, Apple Silicon and Intel. English and Turkish.

I'm the developer. Which app should get an adapter next?
```
Add the GIF (`docs/marketing/demo.gif`) as the first comment.

## Reddit r/MacOS

Promotion only on **Saturdays (UTC)**, flair "Developer Saturday", GitHub repo must be established. Same body as r/macapps; title without `[OS]`:
```
SmartPause: a free, open-source fix for the play/pause key opening Apple Music instead of pausing YouTube
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
