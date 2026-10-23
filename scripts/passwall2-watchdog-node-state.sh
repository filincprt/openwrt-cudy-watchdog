#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

NODE="${1:-}"
NEW="${2:-}"
LABEL="${3:-$NODE}"
STATE_DIR="/tmp/passwall2-failover-state"
FILE="$STATE_DIR/node_${NODE}_state"
mkdir -p "$STATE_DIR" || exit 1

case "$NODE" in primary|backup) ;; *) exit 2 ;; esac
case "$NEW" in online|offline) ;; *) exit 2 ;; esac

OLD="$(cat "$FILE" 2>/dev/null)"
[ "$OLD" = "$NEW" ] && exit 0

case "$OLD:$NEW" in
    :offline)
        /usr/bin/passwall2-watchdog-event "${NODE}_unavailable" "$LABEL узел не проходит три проверки подряд."
        ;;
    online:offline)
        /usr/bin/passwall2-watchdog-event "${NODE}_unavailable" "$LABEL узел не проходит три проверки подряд."
        ;;
    offline:online)
        /usr/bin/passwall2-watchdog-event "${NODE}_restored" "$LABEL узел снова отвечает на проверку."
        ;;
esac

printf '%s\n' "$NEW" > "$FILE"
