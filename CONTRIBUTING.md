# Contributing to SmartPause

Thanks for helping. SmartPause is a small macOS menu bar app; most contributions are **new app adapters**, **bug fixes with a log**, and **translations**.

## Ground rules

- **`main` is protected.** Every change comes in through a pull request. CI (build + tests on GitHub's macOS runner) must be green and the maintainer must approve before merge. Nobody, including the maintainer, force-pushes to `main`.
- **One change per PR.** Keep it focused; a fix and an unrelated refactor are two PRs.
- **Tests come with logic.** Anything touching `Router`, `Settings`, or `L10n` needs a test in `Tests/SmartPauseTests`. Run `swift test` locally before opening the PR.
- **Turkish comments are fine, English is fine.** The codebase has both. User-facing strings go through `L10n.swift` in both languages.
- **No new permissions without discussion.** The app runs with Accessibility only. A change that needs Screen Recording, Microphone, or a private API needs an issue first.

## Reporting a bug

Open a **Bug report** issue and attach `~/Library/Logs/SmartPause.log` (Panel › Setup › Log file › Show). The log records every key press, the decision, and how long it took; without it we are guessing.

## Adding support for an app

1. Check the app is scriptable: `osascript -e 'tell application "X" to ...'` for play/pause/state. Browsers use JavaScript via Apple Events (see `ChromiumAdapter` / `SafariAdapter`).
2. Add an adapter in `Sources/SmartPause/Adapters/`. Implement `isPlaying()` truthfully; Core Audio reports paused apps as still playing for a while, so the adapter's answer decides.
3. Register it in `Router.defaultAdapters`.
4. **Test on the real app and paste the log** in the PR (single press, double press, next/previous). Apps the maintainer does not have installed (Arc, VLC, …) are merged only with a log from a real machine.
5. Add a test with `FakeAdapter` if the adapter changes routing behavior.

## Translations

Add a case to the `Language` enum and a dictionary next to `L.tr` in `L10n.swift`. The `L10nTests` check that every key is translated and placeholders (`%@`, `%d`) match.

## Releases

Only the maintainer cuts releases (`scripts/release.sh` → GitHub Release → Homebrew cask). Contributors do not need to touch `Casks/` or `Resources/Info.plist` version numbers.

## Code of conduct

Be kind, assume good intent, keep discussions about the code. The maintainer may close issues or PRs that don't follow this.
