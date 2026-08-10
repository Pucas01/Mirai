#!/bin/bash
LOG_FILE="$HOME/.cache/quickshell-watchdog.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "watchdog started, waiting for quickshell"

while true; do
    pid=$(pgrep -x quickshell | head -1)

    if [ -z "$pid" ]; then
        sleep 2
        continue
    fi

    log "watching quickshell (pid $pid)"
    tail --pid="$pid" -f /dev/null 2>/dev/null

    if kill -0 "$pid" 2>/dev/null; then
        continue
    fi

    log "quickshell (pid $pid) is no longer running"
    hyprctl notify 3 6000 "rgb(ff6b6b)" "Quickshell crashed"
    sleep 1
done
