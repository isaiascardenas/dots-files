#!/bin/bash
# Query only an already-running Spotify. Bound hangs, including permission prompts.
export LC_CTYPE=en_US.UTF-8
query_spotify() {
    exec /usr/bin/osascript 2>/dev/null <<'APPLESCRIPT'
on singleLine(value)
    set AppleScript's text item delimiters to {return, linefeed}
    set pieces to text items of value
    set AppleScript's text item delimiters to " "
    set value to pieces as text
    set AppleScript's text item delimiters to ""
    return value
end singleLine

if application "Spotify" is not running then return ""
with timeout of 1 second
    tell application "Spotify"
        set playbackState to player state as text
        if playbackState is not "playing" and playbackState is not "paused" then return ""
        set songTitle to name of current track
        set songArtist to artist of current track
    end tell
end timeout
return playbackState & linefeed & my singleLine(songTitle) & linefeed & my singleLine(songArtist)
APPLESCRIPT
}

metadata=$(
    query_spotify &
    query_pid=$!
    (sleep 2; kill "$query_pid" 2>/dev/null) >/dev/null 2>&1 &
    timeout_pid=$!
    wait "$query_pid"
    result=$?
    kill "$timeout_pid" 2>/dev/null
    exit "$result"
) || exit 0

IFS=$'\n' read -r state <<< "$metadata"
case "$state" in
    playing) icon='' ;;
    paused) icon='⏸' ;;
    *) exit 0 ;;
esac
metadata=${metadata#*$'\n'}
title=${metadata%%$'\n'*}
artist=${metadata#*$'\n'}
segment="$icon $title — $artist"
if (( ${#segment} > 60 )); then
    segment="${segment:0:59}…"
fi
# Escape hashes so metadata cannot introduce tmux styles or formats.
printf '%s\n' "${segment//#/##}"
