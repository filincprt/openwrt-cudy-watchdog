#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

# The subscription remark is stored as each imported node's group.
# Fail closed if the configured subscription group resolves to zero or multiple nodes.
GROUP="stealthsurf"
COUNT=0
FOUND=""

for id in $(uci -q show passwall2 | sed -n 's/^passwall2\.\([^=]*\)=nodes$/\1/p'); do
    [ "$(uci -q get "passwall2.$id.add_mode")" = "2" ] || continue
    [ "$(uci -q get "passwall2.$id.group")" = "$GROUP" ] || continue
    COUNT=$((COUNT + 1))
    FOUND="$id"
done

if [ "$COUNT" -ne 1 ]; then
    logger -t passwall2-failover "Primary resolution failed: group=$GROUP nodes=$COUNT; refusing automatic route changes"
    echo "ERROR: expected exactly one imported node in group $GROUP, found $COUNT" >&2
    exit 1
fi

printf '%s\n' "$FOUND"
