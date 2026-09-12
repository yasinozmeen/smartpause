# Security policy

## Supported versions

Only the latest release on the [Releases page](https://github.com/yasinozmeen/smartpause/releases/latest) receives fixes.

## What SmartPause touches

- Reads media key presses through a CGEventTap (needs the Accessibility permission).
- Reads Core Audio's public process list to see which app is outputting sound.
- Sends play/pause commands to apps via AppleScript.
- No network access, no analytics, no accounts, no microphone, no screen recording.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use
[GitHub's private vulnerability reporting](https://github.com/yasinozmeen/smartpause/security/advisories/new)
or email yasinozmeen3@gmail.com. You will get a reply within 7 days. Fixes ship as a new release with credit in the notes unless you prefer otherwise.
