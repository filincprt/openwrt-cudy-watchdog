#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

PRIMARY="PusiSLgE"
BACKUP="fAk268mE"
STATE_DIR="/tmp/passwall2-failover-state"

mkdir -p "$STATE_DIR"

read_count() {
    n="$(cat "$STATE_DIR/$1" 2>/dev/null)"
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
    PROBE_RESULT="$(/usr/bin/timeout -k 2 10 /usr/share/passwall2/test.sh url_test_node "$1" urltest_node 2>/dev/null)"
    case "$PROBE_RESULT" in
        2[0-9][0-9]:*|3[0-9][0-9]:*) return 0 ;;
        *) return 1 ;;
    esac
}

p_ok="$(read_count metric_p_ok)"
p_fail="$(read_count metric_p_fail)"
b_ok="$(read_count metric_b_ok)"
b_fail="$(read_count metric_b_fail)"

if probe "$PRIMARY"; then
    p_result="$PROBE_RESULT"
    p_ok="$(inc "$p_ok")"
    p_fail=0
else
    p_result="$PROBE_RESULT"
    p_ok=0
    p_fail="$(inc "$p_fail")"
fi

if probe "$BACKUP"; then
    b_result="$PROBE_RESULT"
    b_ok="$(inc "$b_ok")"
    b_fail=0
else
    b_result="$PROBE_RESULT"
    b_ok=0
    b_fail="$(inc "$b_fail")"
fi

echo "$p_ok" > "$STATE_DIR/metric_p_ok"
echo "$p_fail" > "$STATE_DIR/metric_p_fail"
echo "$b_ok" > "$STATE_DIR/metric_b_ok"
echo "$b_fail" > "$STATE_DIR/metric_b_fail"

/usr/bin/passwall2-watchdog-publish-metrics "$p_result" "$p_ok" "$p_fail" "$b_result" "$b_ok" "$b_fail"

echo "Metrics-only primary: ${p_result:-no-response}; ok=$p_ok fail=$p_fail"
echo "Metrics-only backup:  ${b_result:-no-response}; ok=$b_ok fail=$b_fail"
