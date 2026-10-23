#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

GROUP="rezerv-stealthsurf"
STATE_DIR="/tmp/passwall2-failover-state"
COUNT=0
FOUND=""

mkdir -p "$STATE_DIR"

for id in $(uci -q show passwall2 | sed -n 's/^passwall2\.\([^=]*\)=nodes$/\1/p'); do
    [ "$(uci -q get "passwall2.$id.add_mode")" = "2" ] || continue
    [ "$(uci -q get "passwall2.$id.group")" = "$GROUP" ] || continue
    COUNT=$((COUNT + 1))
    FOUND="$id"
done

if [ "$COUNT" -eq 0 ]; then
    rm -f "$STATE_DIR/backup_resolver_ambiguity"
    exit 2
fi

if [ "$COUNT" -ne 1 ]; then
    PREV="$(cat "$STATE_DIR/backup_resolver_ambiguity" 2>/dev/null)"
    if [ "$PREV" != "$COUNT" ]; then
        logger -t passwall2-failover "Backup resolver ambiguous: group=$GROUP matches=$COUNT"
        printf '%s\n' "$COUNT" > "$STATE_DIR/backup_resolver_ambiguity"
    fi
    exit 3
fi

if [ -f "$STATE_DIR/backup_resolver_ambiguity" ]; then
    logger -t passwall2-failover "Backup resolver recovered: group=$GROUP matches=1"
    rm -f "$STATE_DIR/backup_resolver_ambiguity"
fi

printf '%s\n' "$FOUND"
