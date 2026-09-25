# Handoff: finish TIDAL support (issue #2)

You are an AI coding agent on a Mac that has the TIDAL desktop app. Your job: prove the TIDAL adapter on branch `claude/smartpause-issue-2-ldtbze` works on a real machine, fix what doesn't, and report back with evidence. The code was written and unit-tested without a Mac. Everything below marked **unverified** is what you are here to settle. The human-facing version of the test steps is [TIDAL-TESTING.md](TIDAL-TESTING.md); read it too.

## Ground rules (from CONTRIBUTING.md, non-negotiable)

- No new permissions. SmartPause runs with Accessibility only (plus per-app Automation for AppleScript apps). Do not add System Events scripting (it triggers a new Automation prompt), Screen Recording, or Input Monitoring.
- No private APIs. MediaRemote is off-limits. Do not patch or inject into TIDAL.
- Router, Settings or L10n changes need a test in `Tests/SmartPauseTests`. `swift test` must pass. User-facing strings go through `Sources/SmartPause/L10n.swift` in English and Turkish.
- One focused change. Keep diffs small and in the codebase's style (dense Swift, short Turkish or English comments explaining *why*).
- Do not merge or push to `main`. Deliver through a pull request (see the end of this file).

## What exists

| File | Role |
|---|---|
| `Sources/SmartPause/Adapters/TidalAdapter.swift` | The adapter. Finds TIDAL's Playback menu through AX, reads item 0 ("Pause" = playing, "Play" = not), presses it, and finds Next/Previous by title. |
| `Sources/SmartPause/Router.swift` | Key decisions. TIDAL is registered last in `defaultAdapters`. `owner(of:_:)` binds a source whose sound comes from a non-app helper (TIDALPlayer) to the app's pid. |
| `Tests/SmartPauseTests/TidalAdapterTests.swift`, `RouterTests.swift` | Menu logic and routing tests (no AX; FakeAdapter). |
| `docs/NOTES.md` › "TIDAL adapter" | Design notes and decisions, in Turkish. |

**Verified from TIDAL 2.43.2's shipped code** (app.asar extracted; not on a live machine):
- Bundle id `com.tidal.desktop`. There is no AppleScript dictionary.
- `app/main/menu/playbackMenu.js`: Playback submenu = `[Play|Pause, —, Previous (⌘←), Next (⌘→), —, Seek back, Seek forward, —, Repeat ▸, Shuffle, —, Volume up, Volume down]`. Only one of Play/Pause exists at a time.
- `app/main/menu/MenuController.js` rebuilds the whole app menu on every `playing` change. The Pause and Play items call separate `pause()`/`resume()` handlers, not a toggle, and use `menuClick`, which doesn't focus the window.
- macOS menu bar order: Apple, TIDAL, File, Edit, **Playback** (AX child index 4), View, Navigation, Window, Help. Titles are localized by TIDAL's own language setting (17 bundles in `app/assets/locale/*.json`). The adapter's title sets cover all of them.
- Sound comes from `TIDALPlayer` (`com.tidal.desktop.player`, a spawned helper, not an app) at the High/Max streaming quality, and from a Chromium helper at Low.

**Unverified. Settle each one:**
1. AXPress on the Playback item works while TIDAL is in the background, hidden (⌘H), or has its window closed, and it neither brings TIDAL forward nor flashes the menu.
2. The AX tree matches: menu bar child 4 is Playback, and separators appear as items.
3. Core Audio reports TIDAL's audio and SmartPause matches it (a `[rank] TIDAL …` line on each press; in the classic modes `[router] çalanlar:` also lists the bundle id, which must start with `com.tidal.desktop`), at both Low and High/Max quality. It stays in the widget (pid mapping).
4. Presses are not silently ignored when another app is fullscreen and frontmost. Other tools report that they are.
5. Delay between a press and the menu title flipping (the adapter logs a check 1 s after each press).
6. Next/Previous work. Behaviour on a cold start (TIDAL just launched, not logged in yet).

## Step 1: preflight (read-only)

```bash
sw_vers; uname -m
defaults read /Applications/TIDAL.app/Contents/Info.plist CFBundleShortVersionString
swift --version          # needs Swift 5.9+; `swift test` may need full Xcode for XCTest
```

If TIDAL is newer than 2.43.2, first check the menu hasn't changed. Terminal needs Accessibility for these reads:

```bash
osascript -e 'tell application "System Events" to tell process "TIDAL" to get name of every menu bar item of menu bar 1'
osascript -e 'tell application "System Events" to tell process "TIDAL" to get name of every menu item of menu 1 of menu bar item 5 of menu bar 1'
```

Expect Playback as the 5th name (1-based), and a first item of "Pause" while music plays and "Play" when paused (separators print as `missing value`). If a title differs, compare it with the sets at the top of `TidalAdapter.swift`. These commands are only a diagnostic; the product must not use System Events.

## Step 2: build, test, install

```bash
git clone -b claude/smartpause-issue-2-ldtbze https://github.com/yasinozmeen/smartpause && cd smartpause
swift test               # all tests must pass before and after your changes
./scripts/bundle.sh && open build/SmartPause.app
```

Accept the move to Applications and grant Accessibility. If the icon stays dimmed (ad-hoc signature mismatch), run `tccutil reset Accessibility dev.smartpause.app`, relaunch, and grant it again. You will need to repeat this after every rebuild unless `bundle.sh` finds an "Apple Development" signing identity. Confirm TIDAL shows **Ready** under the menu bar icon › Apps.

## Step 3: run the scenarios

You can press the media keys yourself with the repo's simulator. The process that runs it (Terminal) needs Accessibility.

```bash
swiftc spikes/simkey.swift -o /tmp/simkey
/tmp/simkey 16        # play/pause   (/tmp/simkey 16 2 = double press)
/tmp/simkey 17        # next
/tmp/simkey 18        # previous
```

Before each scenario, run `: > ~/Library/Logs/SmartPause.log`. Run tests 1–11 from TIDAL-TESTING.md and save the log after each one. Check TIDAL's real state independently of SmartPause with the osascript menu read above ("Pause" means playing). Use `osascript -e 'tell application "TIDAL" to activate'`, ⌘H via System Events, and so on to set up background, hidden and window-closed states.

The log is in Turkish. The glossary is in TIDAL-TESTING.md §5. A healthy single press in the default mode, with TIDAL as the only source, looks like this (order may vary slightly):

```
[tap] media key 16 DOWN
[rank] TIDAL isPlaying=true
[tap] karar yakalandı (… ms)          # decision: handled; the single press runs 350 ms later
[tidal] Pause basıldı, AX sonucu 0
[router] Also paused: TIDAL
[tidal] 1 sn sonra isPlaying=false
```

The raw bundle ids of every sound-making process are logged only in the classic modes (`[router] çalanlar: Name<bundle id>, …`). Switch modes in the panel's Behavior tab when you need them.

## Step 4: if something fails

| Symptom in the log | Likely cause | Where to look |
|---|---|---|
| No `[rank] TIDAL` line while music plays | Core Audio doesn't report the process, or its bundle id doesn't start with `com.tidal.desktop` | Switch to a classic mode to get `[router] çalanlar:` with bundle ids. Then check `AudioDetector.runningOutputProcesses` and `TidalAdapter.bundlePrefixes`. |
| `[router] TIDAL not recognized → …` (or another name for TIDAL's process) | Same as above | same |
| `[rank] TIDAL isPlaying=nil` | Playback menu not found: different index, titles or tree shape | `TidalAdapter.playbackMenu()`, `playbackMenuIndex`, the title sets. Compare with the osascript output. |
| `AX sonucu 0` but `1 sn sonra … (beklenen …)` | Press ignored (fullscreen? hidden app?) or slow buffering | Retry with no fullscreen app. If it's reproducible in a normal state, investigate AXPress on closed Electron menus. Do NOT activate TIDAL as a workaround without discussing it; it switches Spaces. |
| `AX sonucu -25204` / `yanıt vermiyor` | TIDAL didn't answer within 0.5 s | `TidalAdapter.axTimeout`. Measure before raising it; it blocks the key queue. |
| TIDAL comes forward or its menu flashes | AXPress side effect | Report with a screen recording. The design assumes this doesn't happen. |
| Source disappears from the widget right after a press | pid mapping failed and `isAlive` dropped it | `Router.owner(of:_:)`; log `responsiblePID`. |
| Double press with only TIDAL starts Spotify | By design (d1f70ff): with a single source, a double press plays the music app (Spotify) | Not a bug. Note it for the maintainer if a TIDAL-first user would expect otherwise. |

For every fix: keep it minimal, add or adjust a test, run `swift test`, rebuild, reset the permission if needed, and re-run the affected scenarios.

## Step 5: deliver

Open a pull request against `yasinozmeen/smartpause` `main`. Either push your fixes onto a fork of branch `claude/smartpause-issue-2-ldtbze`, or, if you changed nothing, comment on the existing pull request or on issue #2. Include:

- a table of tests 1–11 with pass/fail and a one-line note,
- macOS version, Mac model/chip, TIDAL version, SmartPause commit,
- the relevant log excerpts (skim for anything personal first),
- for each code change: what failed, the log line that showed it, and the test you added.

Follow `.github/PULL_REQUEST_TEMPLATE.md`. Do not bump versions or touch `Casks/`; releases are the maintainer's job.
