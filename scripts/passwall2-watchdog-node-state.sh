#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ "$#" -eq 3 ] || exit 2
NODE="$1"
NEW="$2"
LABEL="$3"

case "$NODE" in primary|backup) ;; *) exit 2 ;; esac
case "$NEW" in online|offline) ;; *) exit 2 ;; esac

DIR="/tmp/passwall2-failover-state"
FILE="$DIR/${NODE}_node_state"
mkdir -p "$DIR" || exit 1
OLD="$(cat "$FILE" 2>/dev/null)"

[ "$OLD" = "$NEW" ] && exit 0
printf '%s\n' "$NEW" > "$FILE" || exit 1

if [ "$NEW" = "offline" ]; then
    if [ "$OLD" = "online" ] || [ -z "$OLD" ]; then
        /usr/bin/passwall2-watchdog-event "${NODE}_unavailable" \
            "$LABEL узел недоступен после трёх неудачных проверок." || true
    fi
elif [ "$OLD" = "offline" ]; then
    /usr/bin/passwall2-watchdog-event "${NODE}_restored" \
        "$LABEL узел снова доступен." || true
fi
