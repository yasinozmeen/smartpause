# Testing TIDAL support (issue #2)

SmartPause can now control the TIDAL desktop app, but the maintainer does not use TIDAL, so the code has never run against a real TIDAL. This guide is for a TIDAL user who is willing to spend about 20 minutes building the test version and sending back one log file. Handing this to an AI coding agent instead? Give it [TIDAL-HANDOFF.md](TIDAL-HANDOFF.md).

**How it works, in one paragraph.** TIDAL has no AppleScript support. But its own **Playback** menu (menu bar › Playback) changes with the play state: the first item reads "Pause" while music plays and "Play" when it doesn't. SmartPause reads that item and presses it through the Accessibility API, the same permission it already uses for the media keys. No new permission, no Automation prompt for TIDAL, nothing installed into TIDAL.

## 1. What you need

- macOS 14.2 or later, the TIDAL desktop app, logged in.
- Apple's command line tools: `xcode-select --install` (skip if you have Xcode).
- 20 minutes, headphones or speakers, and ideally a browser with a YouTube tab for the two-source test.

## 2. Build and install the test version

```bash
git clone -b claude/smartpause-issue-2-ldtbze https://github.com/yasinozmeen/smartpause
cd smartpause
./scripts/bundle.sh            # builds build/SmartPause.app (about a minute)
```

1. If you already use SmartPause, quit it first (menu bar icon › Quit).
2. `open build/SmartPause.app`. It offers to move itself to Applications: accept. It replaces an existing copy (the old one goes to the Trash; `brew reinstall --cask smartpause` brings the release back later).
3. Grant **Accessibility** when asked (System Settings › Privacy & Security › Accessibility).
   A self-built copy has a different signature than the release, so macOS may show SmartPause as enabled while it silently isn't. If the menu bar icon stays dimmed, run `tccutil reset Accessibility dev.smartpause.app`, start SmartPause again and grant it once more.
4. Check you are on the test build: click the menu bar icon › **Apps** tab. **TIDAL** must be in the list and show **Ready** while TIDAL is open.

## 3. Start with a clean log

```bash
: > ~/Library/Logs/SmartPause.log
```

## 4. Try these

Use the play/pause key on your keyboard (and next/previous where noted). SmartPause's default mode: with one app in the widget, a single press plays/pauses it; with two apps, a single press switches between them and a double press plays/pauses the selected one. Note what happened for each line; "worked / didn't / something odd" is enough.

| # | Setup | Do | Expected |
|---|---|---|---|
| 1 | TIDAL playing, another app in front (e.g. Finder) | Press play/pause, wait, press again | TIDAL pauses, then resumes. The widget at the top right shows TIDAL. |
| 2 | Same | Press next, then previous | Next track, then previous track |
| 3 | TIDAL hidden (⌘H) | Press play/pause twice | Pauses, then resumes |
| 4 | TIDAL window closed (⌘W, TIDAL still running) | Press play/pause twice | Pauses, then resumes |
| 5 | Streaming quality (TIDAL › Settings › Streaming) set to **Low**, then to **High** or **Max** | Repeat tests 1 and 6 for each | Works in both. They use different audio engines: Low plays inside TIDAL's web view, High/Max through TIDAL's native player. |
| 6 | Pause TIDAL inside TIDAL (space bar or its own button) | Press play/pause | TIDAL resumes |
| 7 | TIDAL and a YouTube tab both playing | Single press, wait, single press | Switches: one pauses, the other plays, back and forth |
| 8 | Same | Double press | Plays/pauses the app shown on top in the widget |
| 9 | Another app in **fullscreen** in front, TIDAL playing | Press play/pause | TIDAL pauses. **Known risk:** other tools report that menu presses are ignored in this case. |
| 10 | During all of the above | Watch TIDAL | TIDAL should NOT come to the front and its Playback menu should NOT flash open |
| 11 | Optional: TIDAL language set to something other than English (TIDAL › Settings) | Repeat test 1 | Works the same |

## 5. Send the result

Post on [issue #2](https://github.com/yasinozmeen/smartpause/issues/2) (or the pull request linked from it):

- your results per test number,
- macOS version, Mac model (Apple Silicon / Intel), TIDAL version (TIDAL › About TIDAL),
- the log: `~/Library/Logs/SmartPause.log` (menu bar icon › Setup › Log file › Show). It contains app names and timings, not track titles; still, skim it before posting.

**Reading the log** (it is written in Turkish; the useful lines):

| Line | Meaning |
|---|---|
| `[rank] TIDAL isPlaying=true` / `false` / `nil` | TIDAL is making sound, and this is what SmartPause read from its menu. `nil` means the Playback menu was not recognised. No `[rank] TIDAL` line while TIDAL plays means SmartPause didn't see its audio. |
| `[router] TIDAL not recognized → …` | SmartPause saw the sound but didn't match it to TIDAL |
| `[tidal] Pause basıldı, AX sonucu 0` | "Pause pressed, Accessibility result 0" (0 = success, -25204 = TIDAL didn't answer in time) |
| `[tidal] 1 sn sonra isPlaying=false` | Checked one second later: the press took effect. A trailing `(beklenen …)` ("expected …") means it did not, or TIDAL was still buffering. |
| `[tidal] Playback menüsü bulunamadı` | "Playback menu not found" |
| `[tap] karar yakalandı (N ms)` / `passthrough` | The key was handled by SmartPause / handed to macOS; N = how long the decision took |

## 6. Going back

`brew reinstall --cask smartpause`, or download the latest release. The test build uses the same settings file, so nothing else to clean up.
