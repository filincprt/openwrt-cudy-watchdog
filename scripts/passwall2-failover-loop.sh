#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

while :; do
    /usr/bin/passwall2-failover 2>&1 | while IFS= read -r line; do
        logger -t passwall2-watchdog "$line"
    done

    MODE="$(uci -q get ha_watchdog.main.mode 2>/dev/null)"

    case "$MODE" in
        primary|backup|off)
            /usr/bin/passwall2-watchdog-probe-metrics 2>&1 | while IFS= read -r line; do
                logger -t passwall2-watchdog-metrics "$line"
            done
            RANDOM_VALUE="$RANDOM"
            WAIT=$((180 + RANDOM_VALUE % 121))
            ;;
        *)
            RANDOM_VALUE="$RANDOM"
            WAIT=$((5 + RANDOM_VALUE % 11))
            ;;
    esac

    logger -t passwall2-watchdog "Next cycle in ${WAIT}s (mode=${MODE:-auto})"
    sleep "$WAIT"
done
