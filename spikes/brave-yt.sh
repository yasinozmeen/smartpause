#!/bin/bash
# Kullanım: brave-yt.sh play|state
case "$1" in
  play)  JS='document.querySelector(\"video\").play(); \"ok\"' ;;
  state) JS='\"paused=\"+document.querySelector(\"video\").paused' ;;
esac
osascript <<APPLESCRIPT
tell application "Brave Browser"
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "youtube.com/watch" then return execute t javascript "$JS"
    end repeat
  end repeat
  return "sekme yok"
end tell
APPLESCRIPT
