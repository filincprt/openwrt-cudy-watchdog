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
/usr/bin/timeout -k 2 10 /usr/share/passwall2/test.sh url_test_node PusiSLgE urltest_node
echo "EXIT_CODE=$?"
/usr/bin/timeout -k 2 10 /usr/share/passwall2/test.sh url_test_node fAk268mE urltest_node
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
