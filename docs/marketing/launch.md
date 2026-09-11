# SmartPause launch kit

Everything below is ready to paste. Order matters: the first three days decide most of the traffic, so post the high-leverage channels first and space the rest out over two weeks.

**Assets:** GIF `docs/marketing/demo.gif`, stills `1-hero.png … 5-music.png` (2560×1600), icon `design/icon/icon-1024.png`.
**Link:** https://github.com/yasinozmeen/smartpause
**One-liner:** SmartPause makes the macOS play/pause key pause what is actually playing, not Apple Music.

---

## Day 1 — high leverage

### 1. Hacker News (Show HN) — Tuesday–Thursday, 14:00–16:00 Türkiye (07:00–09:00 PT)

**Title (80 chars max):**
`Show HN: SmartPause – macOS play/pause key that pauses what's actually playing`

**First comment (post it yourself right after submitting):**

> I built this because pressing play/pause on my Mac opened Apple Music instead of pausing YouTube. macOS routes the media key to whatever it last remembers as "Now Playing", which is often wrong and sometimes nothing.
>
> SmartPause is a small menu bar app. It catches the key with a CGEventTap, asks Core Audio which process is outputting sound right now (public API since 14.2, no microphone permission, zero CPU when idle), and sends the command to that app via AppleScript. If two apps are playing, a single press switches between them and a double press plays/pauses the selected one; a small widget shows what happened.
>
> Things I learned the hard way, in case useful: Core Audio keeps reporting a paused app as "outputting" for a while, so the adapter has to ask the app itself; a stalled browser tab can block an Apple Event for 120 seconds, which made macOS disable the event tap, so the tap now lives on its own thread with a 4-second cap per command; ad-hoc code signatures change every build, which silently drops the Accessibility permission.
>
> Swift, MIT, Homebrew cask. Arc and VLC adapters exist but I don't have those apps, so real-machine logs are welcome.

### 2. Reddit

Post the same day to **r/macapps** (best fit), then **r/MacOS** the next day. Reddit dislikes cross-posting within hours. Use the GIF as the post media where allowed; otherwise a link post with the GitHub URL and the text as a comment.

**Title:** `I made a free menu bar app that stops the play/pause key from opening Apple Music`

**Body:**

> If you've ever hit play/pause to stop a YouTube video and watched Apple Music open instead: that's macOS sending the key to whatever it last remembers, not to what's making sound.
>
> SmartPause fixes that. It looks at which app is actually outputting audio right now and sends the key there. Works with Spotify, Apple Music, VLC, Chrome, Brave, Safari (Arc untested). Two apps playing? One press switches, double press plays/pauses the selected one, and a small widget at the top right shows what it did.
>
> Free, open source (MIT), no analytics, needs only the Accessibility permission. `brew install --cask yasinozmeen/smartpause/smartpause` or grab the zip.
>
> https://github.com/yasinozmeen/smartpause
>
> Happy to hear which apps you'd want supported.

Other subreddits, one per day after that: r/apple (weekend self-promo rules, check), r/spotify ("play/pause key opens Apple Music" is a known complaint there), r/macgaming (no), r/opensource.

### 3. X / Twitter + Mastodon (mastodon.social, #macOS #indiedev #opensource)

> Play/pause on your Mac opens Apple Music instead of pausing YouTube? macOS sends the key to whatever it *remembers*, not to what's playing.
>
> I made SmartPause: it finds the app actually making sound and pauses that. Free, open source, Swift.
>
> [GIF]
> https://github.com/yasinozmeen/smartpause

Thread reply 1: how it works (Core Audio + event tap, three sentences). Reply 2: the 120-second Apple Event story. Reply 3: "which app should I add next?"

---

## Day 2–7 — directories and lists (each is a one-time submission, evergreen traffic)

| Where | What to do | Note |
|---|---|---|
| **Product Hunt** | Schedule a launch for a Tuesday 00:01 PT. Tagline: "The play/pause key, finally aimed at what's playing." Gallery: demo.gif first, then the 5 stills. | Needs a hunter or self-hunt; ask 5 friends to be online the first hour. |
| **AlternativeTo** | Add SmartPause as an alternative to noTunes and BeardedSpice. | Free listing, steady search traffic for "noTunes alternative". |
| **awesome-mac** (jaywcjlove/awesome-mac) | PR under "Audio and Video Tools". One line: `SmartPause – Routes the play/pause key to the app that is actually playing. ![Open-Source Software][OSS Icon] ![Freeware][Freeware Icon]` | Most starred Mac list; PRs merge within days. |
| **awesome-menubar** (kb-nas/awesome-menubar or similar) | Same one-liner. | |
| **MacUpdate** | Submit the zip with the icon and 3 screenshots. | Old but still ranks. |
| **Homebrew** | Already done (tap). Later: once 30+ stars and 1 release old, submit to `homebrew-cask` main so users can `brew install --cask smartpause` without the tap. | Cask requires notarized or at least stable download; check current rules. |
| **Lobsters** | Only if you have an invite. Tag `mac`, `swift`. | Small but high quality. |
| **Indie Hackers** | "I built a free macOS utility, here's what I learned" post. | Reuse the HN comment. |
| **Dev.to / Medium** | Technical write-up: "Why the macOS play/pause key goes to the wrong app, and how I fixed it" (Core Audio process API, event tap threading, TCC + code signing). | Long-tail search traffic; link back to the repo. |

---

## GitHub itself (do these first, they take 10 minutes)

- Description (English): `Routes the macOS play/pause key to the app that is actually playing. Menu bar, Swift, no Apple Music surprises.`
- Topics: `macos` `menubar` `swift` `media-keys` `spotify` `apple-music` `youtube` `core-audio` `cgeventtap` `applescript` `productivity` `open-source`
- Social preview image: Settings › Social preview → upload `docs/marketing/1-hero.png` (this is what shows on X/Slack/Discord when the link is pasted).
- Pin the repo on your profile.
- Enable "Sponsors" only if you want; skip otherwise.

---

## Replies you will get, and answers

- **"Why not just use noTunes?"** noTunes only blocks Music from launching. SmartPause also routes the key to the right app and handles two sources.
- **"BeardedSpice?"** Unmaintained since 2019, breaks on new macOS, needs browser extensions. SmartPause needs none.
- **"Does it need Screen Recording / Microphone?"** No. Accessibility only. Audio detection is Core Audio's public process list.
- **"Is it notarized?"** Not yet; it is ad-hoc signed. Right-click › Open on first launch. Notarization is planned once the project justifies the Developer ID cost.
- **"Arc / VLC?"** Adapters exist, untested. Paste `~/Library/Logs/SmartPause.log` in an issue and it gets fixed.
