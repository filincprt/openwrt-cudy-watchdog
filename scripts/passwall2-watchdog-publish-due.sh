#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

STATE="/tmp/passwall2-failover-state"
LAST_FILE="$STATE/metrics_last_publish"
INTERVAL_FILE="$STATE/metrics_interval"

mkdir -p "$STATE"

NOW="$(date +%s)"
LAST="$(cat "$LAST_FILE" 2>/dev/null)"
INTERVAL="$(cat "$INTERVAL_FILE" 2>/dev/null)"

case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
case "$INTERVAL" in
    ''|*[!0-9]*)
        INTERVAL=$((180 + RANDOM % 121))
        echo "$INTERVAL" > "$INTERVAL_FILE"
        ;;
    *)
        if [ "$INTERVAL" -lt 180 ] || [ "$INTERVAL" -gt 300 ]; then
            INTERVAL=$((180 + RANDOM % 121))
            echo "$INTERVAL" > "$INTERVAL_FILE"
        fi
        ;;
esac

ELAPSED=$((NOW - LAST))

if [ "$ELAPSED" -lt "$INTERVAL" ]; then
    REMAIN=$((INTERVAL - ELAPSED))
    echo "Metrics publication skipped; next update in ${REMAIN}s"
    exit 0
fi

if /usr/bin/passwall2-watchdog-publish-metrics "$@"; then
    echo "$NOW" > "$LAST_FILE"
    INTERVAL=$((180 + RANDOM % 121))
    echo "$INTERVAL" > "$INTERVAL_FILE"
    echo "Metrics published; next interval ${INTERVAL}s"
else
    echo "Metrics publication failed; will retry next cycle"
    exit 1
fi
