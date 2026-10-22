#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

P_RESULT="${1:-}"
P_OK="${2:-0}"
P_FAIL="${3:-0}"
B_RESULT="${4:-}"
B_OK="${5:-0}"
B_FAIL="${6:-0}"

P_DISPLAY="${P_RESULT:-no-response}"
B_DISPLAY="${B_RESULT:-no-response}"

case "$P_RESULT" in
    2[0-9][0-9]:*|3[0-9][0-9]:*)
        P_STATUS="online"
        P_HTTP="${P_RESULT%%:*}"
        P_RTT="$(echo "$P_RESULT" | awk -F: '{printf "%.0f", $2 * 1000}')"
        ;;
    *)
        P_STATUS="offline"
        P_HTTP="no-response"
        P_RTT="unknown"
        ;;
esac

case "$B_RESULT" in
    2[0-9][0-9]:*|3[0-9][0-9]:*)
        B_STATUS="online"
        B_HTTP="${B_RESULT%%:*}"
        B_RTT="$(echo "$B_RESULT" | awk -F: '{printf "%.0f", $2 * 1000}')"
        ;;
    *)
        B_STATUS="offline"
        B_HTTP="no-response"
        B_RTT="unknown"
        ;;
esac

CHECKED="$(date '+%Y-%m-%d %H:%M:%S')"

# Discard accumulated staged telemetry before writing a fresh bounded snapshot.
uci revert ha_watchdog_metrics

uci set "ha_watchdog_metrics.nodes.primary_result=$P_DISPLAY" || exit 1
uci set "ha_watchdog_metrics.nodes.primary_ok=$P_STATUS" || exit 1
uci set "ha_watchdog_metrics.nodes.primary_failures=$P_FAIL" || exit 1
uci set "ha_watchdog_metrics.nodes.primary_rtt_ms=$P_RTT" || exit 1
uci set "ha_watchdog_metrics.nodes.primary_checked_at=$CHECKED" || exit 1
uci set "ha_watchdog_metrics.nodes.primary_http=$P_HTTP" || exit 1

uci set "ha_watchdog_metrics.nodes.backup_result=$B_DISPLAY" || exit 1
uci set "ha_watchdog_metrics.nodes.backup_ok=$B_STATUS" || exit 1
uci set "ha_watchdog_metrics.nodes.backup_failures=$B_FAIL" || exit 1
uci set "ha_watchdog_metrics.nodes.backup_rtt_ms=$B_RTT" || exit 1
uci set "ha_watchdog_metrics.nodes.backup_checked_at=$CHECKED" || exit 1
uci set "ha_watchdog_metrics.nodes.backup_http=$B_HTTP" || exit 1

uci set "ha_watchdog_metrics.nodes.last_check=$CHECKED" || exit 1
uci set "ha_watchdog_metrics.nodes.primary_summary=$P_STATUS | HTTP $P_HTTP | RTT $P_RTT ms | failures $P_FAIL | checked $CHECKED" || exit 1
uci set "ha_watchdog_metrics.nodes.backup_summary=$B_STATUS | HTTP $B_HTTP | RTT $B_RTT ms | failures $B_FAIL | checked $CHECKED" || exit 1
