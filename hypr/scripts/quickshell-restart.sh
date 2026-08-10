#!/bin/bash
pid=$(pgrep -x quickshell | head -1)

if [ -n "$pid" ]; then
    kill -TERM "$pid"
    for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
fi

nohup quickshell >/dev/null 2>&1 &
disown
