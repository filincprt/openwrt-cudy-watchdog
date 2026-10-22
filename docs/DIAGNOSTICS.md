# Diagnostic command cookbook

Commands below are read-only unless noted.

## Service / schedule

```sh
/etc/init.d/passwall2-failover-watchdog status
ls -l /etc/rc.d/*passwall2-failover-watchdog
cat /etc/crontabs/root
ps w | grep -E '[p]asswall2-failover-loop|[p]asswall2-failover-core'
```

## Current mode, state and counters

```sh
uci -q get ha_watchdog.main.mode
uci -q get ha_watchdog.main.status
uci -q get passwall2.rulenode.default_node
for f in /tmp/passwall2-failover-state/*; do echo "--- $f"; cat "$f"; done
ls -ld /tmp/passwall2-failover.lock 2>&1
```

## Logs

```sh
logread | grep 'passwall2-watchdog' | tail -n 40
logread | grep -Ei 'passwall2-failover|failover' | tail -n 80
```

## Manually test both nodes

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node PusiSLgE urltest_node
echo "EXIT_CODE=$?"
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node fAk268mE urltest_node
echo "EXIT_CODE=$?"
ps w | grep -E '[u]rl_test_PusiSLgE|[u]rl_test_fAk268mE'
```

Observed healthy output was HTTP `204` and exit code `0`. A successful probe checks HTTP reachability via a temporary proxy; manual use of a node alone does not prove the scheduled probe succeeded.

## Firewall / interfaces

```sh
/etc/init.d/firewall status
fw4 print >/dev/null && echo 'fw4: OK'
uci show firewall
ubus call network.interface.wan status
ubus call network.interface.wan6 status
ip route show default
ip -6 route show default
```

## Shell syntax

OpenWrt build did not have `nl`; use `sed -n '1,150p' FILE` to inspect numbered ranges, or `grep -n` to locate matching lines.


## Telemetry throttle

In automatic mode, health probes continue every core cycle, but publication into UCI is limited by `passwall2-watchdog-publish-due` to a randomized 180–300 seconds.

```sh
cat /tmp/passwall2-failover-state/metrics_last_publish 2>/dev/null
cat /tmp/passwall2-failover-state/metrics_interval 2>/dev/null
uci -q get ha_watchdog_metrics.nodes.last_check
uci -q get ha_watchdog_metrics.nodes.primary_summary
uci -q get ha_watchdog_metrics.nodes.backup_summary
logread -e passwall2-watchdog | tail -n 30
```

The files under `/tmp/passwall2-failover-state` are volatile and reset on reboot. A missing timestamp immediately after reboot can mean the first publication has not yet happened.


## Telemetry cadence and current control mode

```sh
echo "MODE=$(uci -q get ha_watchdog.main.mode)"
echo "ROUTE=$(uci -q get passwall2.rulenode.default_node)"
/etc/init.d/passwall2-failover-watchdog status
echo "LAST_PUBLISH=$(cat /tmp/passwall2-failover-state/metrics_last_publish 2>/dev/null)"
echo "PUBLISH_INTERVAL=$(cat /tmp/passwall2-failover-state/metrics_interval 2>/dev/null)"
echo "LAST_METRICS=$(uci -q get ha_watchdog_metrics.nodes.last_check)"
logread -e passwall2-watchdog | tail -n 40
logread -e passwall2-watchdog-metrics | tail -n 20
```

In auto mode, compare ordinary core probe log lines with changes to `last_check`: probes should continue on every cycle while the publication gate allows UCI metrics to update only every randomized 180–300 seconds. This behavior was connected and syntax-checked but still requires live cadence verification. In manual modes, the metrics-only probe itself runs on the 180–300 second loop schedule.

The live core and manual metrics checker use `timeout -k 2 15`. A standalone test example:

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node PRIMARY_NODE_ID urltest_node
echo "EXIT_CODE=$?"
```

Replace the placeholder with a verified node ID. Do not publish actual subscription or credential-bearing config output.
