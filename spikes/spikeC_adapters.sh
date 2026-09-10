#!/bin/bash
# Spike C: AppleScript ile hedefe play/pause. Kullanım: ./spikeC_adapters.sh <spotify|music|vlc|brave|chrome|safari> [state]
case "$1" in
  spotify) osascript -e 'tell application "Spotify" to playpause' -e 'tell application "Spotify" to player state as string' ;;
  music)   osascript -e 'tell application "Music" to playpause' ;;
  vlc)     osascript -e 'tell application "VLC" to play' ;;   # VLC'de "play" toggle'dır
  brave|chrome)
    app=$([ "$1" = brave ] && echo "Brave Browser" || echo "Google Chrome")
    # Sekmeleri tara; ses çalan (audible) ya da media elementi playing olan sekmeyi bul ve toggle et.
    osascript <<APPLESCRIPT
tell application "$app"
  set js to "(function(){var m=[...document.querySelectorAll('video,audio')].find(e=>!e.paused);if(m){m.pause();return 'paused:'+location.host}return 'none'})()"
  repeat with w in windows
    repeat with t in tabs of w
      try
        set r to execute t javascript js
        if r is not "none" then return r
      end try
    end repeat
  end repeat
  return "no media tab"
end tell
APPLESCRIPT
    ;;
  safari) osascript -e 'tell application "Safari" to do JavaScript "var m=[...document.querySelectorAll(\"video,audio\")].find(e=>!e.paused); m?(m.pause(),\"paused\"):\"none\"" in current tab of front window' ;;
esac
