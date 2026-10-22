#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

PRIMARY="PusiSLgE"
BACKUP="fAk268mE"
CONF="passwall2.rulenode.default_node"
STATE="/tmp/passwall2-failover-state"
LOCK="/tmp/passwall2-failover.lock"

mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' 0 1 2 15
mkdir -p "$STATE"

read_count() {
    n="$(cat "$STATE/$1" 2>/dev/null)"
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    [ "$n" -gt 3 ] && n=3
    echo "$n"
}

inc() {
    if [ "$1" -lt 3 ]; then
        echo $(($1 + 1))
    else
        echo 3
    fi
}

probe() {
    PROBE_RESULT="$(/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node "$1" urltest_node 2>/dev/null)"
    case "$PROBE_RESULT" in
        2[0-9][0-9]:*|3[0-9][0-9]:*) return 0 ;;
        *) return 1 ;;
    esac
}

p_ok="$(read_count p_ok)"
p_fail="$(read_count p_fail)"
b_ok="$(read_count b_ok)"
b_fail="$(read_count b_fail)"

if probe "$PRIMARY"; then
    p_good=1
    p_result="$PROBE_RESULT"
    p_ok="$(inc "$p_ok")"
    p_fail=0
else
    p_good=0
    p_result="$PROBE_RESULT"
    p_ok=0
    p_fail="$(inc "$p_fail")"
fi

if probe "$BACKUP"; then
    b_good=1
    b_result="$PROBE_RESULT"
    b_ok="$(inc "$b_ok")"
    b_fail=0
else
    b_good=0
    b_result="$PROBE_RESULT"
    b_ok=0
    b_fail="$(inc "$b_fail")"
fi

echo "$p_ok" > "$STATE/p_ok"
echo "$p_fail" > "$STATE/p_fail"
echo "$b_ok" > "$STATE/b_ok"
echo "$b_fail" > "$STATE/b_fail"

/usr/bin/passwall2-watchdog-publish-due "$p_result" "$p_ok" "$p_fail" "$b_result" "$b_ok" "$b_fail"

current="$(uci -q get "$CONF")"
desired="$current"

case "$current" in
    "$PRIMARY")
        if [ "$p_fail" -ge 3 ]; then
            if [ "$b_good" -eq 1 ]; then
                desired="$BACKUP"
            elif [ "$b_fail" -ge 3 ]; then
                desired="_direct"
            fi
        fi
        ;;
    "$BACKUP")
        if [ "$p_ok" -ge 3 ]; then
            desired="$PRIMARY"
        elif [ "$b_fail" -ge 3 ]; then
            if [ "$p_good" -eq 1 ]; then
                desired="$PRIMARY"
            elif [ "$p_fail" -ge 3 ]; then
                desired="_direct"
            fi
        fi
        ;;
    "_direct")
        if [ "$p_ok" -ge 3 ]; then
            desired="$PRIMARY"
        elif [ "$b_ok" -ge 3 ]; then
            desired="$BACKUP"
        fi
        ;;
    *)
        if [ "$p_good" -eq 1 ]; then
            desired="$PRIMARY"
        elif [ "$p_fail" -ge 3 ] && [ "$b_good" -eq 1 ]; then
            desired="$BACKUP"
        elif [ "$p_fail" -ge 3 ] && [ "$b_fail" -ge 3 ]; then
            desired="_direct"
        fi
        ;;
esac

echo "Primary: $p_result; ok=$p_ok fail=$p_fail"
echo "Backup:  $b_result; ok=$b_ok fail=$b_fail"
echo "Current: $current; target: $desired"

if [ "$desired" != "$current" ]; then
    uci set "$CONF=$desired" || exit 1
    uci commit passwall2
    /etc/init.d/passwall2 restart
    sleep 2

    if ! /tmp/etc/passwall2/bin/xray run -test -config /tmp/etc/passwall2/acl/acl_default.json >/dev/null 2>&1; then
        logger -t passwall2-failover "Xray validation failed; restoring $current"
        uci set "$CONF=$current"
        uci commit passwall2
        /etc/init.d/passwall2 restart
    else
        logger -t passwall2-failover "Route changed: $current -> $desired"
    fi
fi
