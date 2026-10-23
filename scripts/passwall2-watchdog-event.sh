#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ "$#" -ge 2 ] || exit 2
CODE="$1"
shift
MESSAGE="$*"
STATE_DIR="/tmp/passwall2-failover-state"
mkdir -p "$STATE_DIR" || exit 1

case "$CODE" in
    ''|*[!a-zA-Z0-9_-]*) exit 2 ;;
esac

FINGERPRINT="$CODE|$MESSAGE"
PREV="$(cat "$STATE_DIR/last_event_fingerprint" 2>/dev/null)"
[ "$FINGERPRINT" = "$PREV" ] && exit 0

SEQ="$(cat "$STATE_DIR/event_seq" 2>/dev/null)"
case "$SEQ" in ''|*[!0-9]*) SEQ=0 ;; esac
SEQ=$((SEQ + 1))

EVENT_ID="$(date +%s)-$SEQ"
EVENT_AT="$(date '+%Y-%m-%d %H:%M:%S')"
uci set "ha_watchdog.main.event_code=$CODE" || exit 1
uci set "ha_watchdog.main.event_message=$MESSAGE" || exit 1
uci set "ha_watchdog.main.event_at=$EVENT_AT" || exit 1
uci set "ha_watchdog.main.event_id=$EVENT_ID" || exit 1
uci commit ha_watchdog || exit 1

printf '%s\n' "$FINGERPRINT" > "$STATE_DIR/last_event_fingerprint"
printf '%s\n' "$SEQ" > "$STATE_DIR/event_seq"
logger -t passwall2-watchdog-event "$CODE: $MESSAGE"

# Read the secret webhook URL from the locally installed wrapper at runtime.
# Never print or commit the active webhook URL/token.
WRAPPER="/usr/bin/passwall2-failover"
HA_WEBHOOK_URL="$(sed -n -e 's@^[[:space:]]*HA_WEBHOOK_URL="\(http[^"]*/api/webhook/[^"]*\)".*@\1@p' -e 's@.*-X POST \(http[^ ]*/api/webhook/[^ ]*\).*@\1@p' "$WRAPPER" 2>/dev/null | head -n 1)"
case "$HA_WEBHOOK_URL" in
    http*/api/webhook/*)
        case "$HA_WEBHOOK_URL" in
            *REDACTED*|*REPLACE*|*CHANGE_ME*)
                logger -t passwall2-watchdog-event "Webhook placeholder found; event saved to UCI but not sent to HA"
                ;;
            *)
                /usr/bin/curl -fsS --max-time 3 -X POST "$HA_WEBHOOK_URL" >/dev/null 2>&1 || \
                    logger -t passwall2-watchdog-event "HA webhook POST failed"
                ;;
        esac
        ;;
    *)
        logger -t passwall2-watchdog-event "HA webhook URL not found in failover wrapper; event saved to UCI only"
        ;;
esac
