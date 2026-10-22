# Deployment guide: OpenWrt + PassWall2, with or without Home Assistant

This guide describes a careful manual deployment path. It is not a one-click installer. Commands are intentionally staged so you can inspect each result. Adapt the node IDs, paths, timeout, test URL and validation command to the exact router and PassWall2 version.

## 0. Requirements and scope

- OpenWrt with working SSH/LuCI access and PassWall2 installed.
- Two valid PassWall2 proxy nodes (primary and backup) plus the special `_direct` target supported by the local PassWall2/Xray configuration.
- `/usr/share/passwall2/test.sh` and the `url_test_node` action present.
- `/usr/bin/timeout`, `curl`, `uci`, `logger`, `awk`, and BusyBox `ash`.
- Optional: a reachable Home Assistant instance and the compatible OpenWrt HA integration.

**Do not proceed using the example IDs below unless they really match your router.** In the original lab, `PusiSLgE` was primary and `fAk268mE` backup; these are examples, not portable IDs. Subscription refresh can change IDs.

## 1. Back up first

Run locally over SSH and copy the resulting files somewhere off the router:

```sh
mkdir -p /root/watchdog-backup
cp -p /etc/config/passwall2 /root/watchdog-backup/passwall2
cp -p /etc/config/firewall /root/watchdog-backup/firewall
cp -p /etc/config/network /root/watchdog-backup/network
cp -p /etc/config/dropbear /root/watchdog-backup/dropbear
cp -p /usr/bin/passwall2-failover /root/watchdog-backup/passwall2-failover 2>/dev/null
cp -p /usr/bin/passwall2-failover-core /root/watchdog-backup/passwall2-failover-core 2>/dev/null
cp -p /usr/bin/passwall2-failover-loop /root/watchdog-backup/passwall2-failover-loop 2>/dev/null
cp -p /etc/init.d/passwall2-failover-watchdog /root/watchdog-backup/passwall2-failover-watchdog 2>/dev/null
```

Keep this directory private; PassWall2 config can contain sensitive data. Do not upload it to this repository.

## 2. Discover the local node IDs and probe capability

Inspect PassWall2 configuration locally. Do not paste subscription URLs or node credentials into issues/chats.

```sh
uci show passwall2 | grep -E 'nodes|node|default_node'
ls -l /usr/share/passwall2/test.sh /usr/bin/timeout
uci -q get passwall2.rulenode.default_node
```

Choose the exact UCI node IDs for primary and backup from your local config. Test each one independently while the current route and management access are healthy:

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node YOUR_PRIMARY_ID urltest_node
echo "EXIT_CODE=$?"
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node YOUR_BACKUP_ID urltest_node
echo "EXIT_CODE=$?"
```

A response like `204:0.35...` with exit code 0 is a successful test. A blank response is not enough to diagnose a server block; check logs, DNS, WAN, Xray and the PassWall2 test script.

## 3. Understand the files before installation

Reference files under `scripts/` are sanitized snapshots. Read them and compare with the live scripts from your exact PassWall2 build. The expected roles are:

- `passwall2-failover`: mode wrapper; manual route pins or automatic core invocation; optional HA status webhook.
- `passwall2-failover-core`: probes, counters, decision rules and route change validation.
- `passwall2-failover-loop`: persistent loop and jittered schedule.
- `passwall2-failover-watchdog.init`: procd service.
- `passwall2-watchdog-probe-metrics.sh`: manual-mode telemetry probes, no route changes.
- `passwall2-watchdog-publish-metrics.sh`: converts probe output into UCI metrics.
- `passwall2-watchdog-publish-due.sh`: throttles telemetry publication in automatic mode.

The repository does not currently promise that every reference script exactly matches the live router. Compare before copying. Adapt the core's Xray validation path if it differs locally.

## 4. Deploy the watchdog core (no Home Assistant required)

Home Assistant is optional. The watchdog can use UCI for its own mode/status and run without HA, but the current example wrapper includes an optional webhook integration. For a no-HA setup, remove/comment out only the webhook `curl` call in `set_status()`; keep the UCI status update if you want status available to local diagnostics. Do not leave a fake token or real secret in a published script.

Before activating:
1. Replace `PRIMARY` and `BACKUP` IDs in core and wrapper.
2. Verify the local PassWall2 test command and Xray validation path.
3. Verify `_direct` is the correct direct-routing target for this configuration.
4. Confirm the wrapper's mode mapping and UCI package/section names.
5. Run `sh -n` on every script.

Copy reviewed files to their intended live paths (only after comparing and adapting):

| Repository file | Live path |
|---|---|
| `scripts/passwall2-failover-core.sh` | `/usr/bin/passwall2-failover-core` |
| `scripts/passwall2-failover-loop.sh` | `/usr/bin/passwall2-failover-loop` |
| `scripts/passwall2-failover-watchdog.init` | `/etc/init.d/passwall2-failover-watchdog` |
| `scripts/passwall2-failover.sh.example` | `/usr/bin/passwall2-failover` after local adaptation |

The metrics scripts are optional; install all three together only after checking their current snapshots and the publisher call path. Do not install an old snapshot over a newer live script blindly.

```sh
chmod 755 /usr/bin/passwall2-failover-core /usr/bin/passwall2-failover-loop /usr/bin/passwall2-failover
chmod 755 /etc/init.d/passwall2-failover-watchdog
sh -n /usr/bin/passwall2-failover-core
sh -n /usr/bin/passwall2-failover
sh -n /usr/bin/passwall2-failover-loop
```

Enable only after read-only checks and isolated probes pass:

```sh
/etc/init.d/passwall2-failover-watchdog enable
/etc/init.d/passwall2-failover-watchdog start
/etc/init.d/passwall2-failover-watchdog status
```

Avoid running the legacy cron watchdog at the same time. The lab removed `* * * * * /usr/bin/passwall2-failover` because the procd loop is the single scheduler. Do not delete unrelated cron jobs; the lab retained its daily PassWall2 subscription refresh.

## 5. UCI mode and state

The lab uses these settings:

```sh
uci show ha_watchdog
uci get passwall2.rulenode.default_node
```

Control modes:
- `auto`: automatic health decisions.
- `primary`: pin primary; no automatic failover.
- `backup`: pin backup; no automatic failover.
- `off`: pin `_direct`; no automatic failover.

In the lab, mode values are stored under `ha_watchdog.main.mode`, and status under `ha_watchdog.main.status`. Your local UCI schema may need to be created/adapted. Do not assume setting `auto` means the PassWall2 route field itself is an automatic URLTest group.

## 6. Optional telemetry without HA

If telemetry scripts are installed, inspect the live fields:

```sh
uci show ha_watchdog_metrics
logread -e passwall2-watchdog-metrics | tail -n 20
```

Telemetry values are staged in UCI and not committed on every probe to avoid repeated flash writes. They are volatile and reset after reboot until the next check. The publisher throttle is meant to limit **telemetry writes**, not health probes in automatic mode.

## 7. Add Home Assistant integration (optional)

The HA integration is not required for failover. For HA:
1. Install/configure a compatible `ha-openwrt` integration using a dedicated, restricted credential if supported by your environment.
2. Confirm `openwrt.uci_get` can read `ha_watchdog.main.mode` and `ha_watchdog_metrics.nodes.primary_summary`.
3. Create helpers through HA UI. In the original dashboard, `input_select.passwall2_mode` options are `Авто`, `Основной узел`, `Резервный узел`, `VPN выключен`; status uses `input_select.passwall2_status`.
4. Create UI automations to map the selected mode to UCI and invoke the wrapper, and to poll the telemetry summaries into `input_text` helpers.
5. If using a webhook for status changes, generate a fresh random token in HA and store the full URL only in the live router wrapper. Never put it in Git.
6. Verify HA is reading the live UCI values, not a stale helper. Test a manual mode change before enabling unattended automatic control.

Example UCI read commands for HA integration to execute:

```sh
uci -q get ha_watchdog.main.mode
uci -q get ha_watchdog.main.status
uci -q get ha_watchdog_metrics.nodes.primary_summary
uci -q get ha_watchdog_metrics.nodes.backup_summary
```

The exact action response structure and automation YAML depend on the installed integration version. Do not paste assumed response keys; inspect the action in Developer Tools first.

## 8. Verify after install

```sh
/etc/init.d/passwall2-failover-watchdog status
ps w | grep -E '[p]asswall2-failover-loop|[p]asswall2-failover-core'
logread -e passwall2-watchdog | tail -n 40
uci -q get ha_watchdog.main.mode
uci -q get passwall2.rulenode.default_node
uci -q get ha_watchdog_metrics.nodes.primary_summary
uci -q get ha_watchdog_metrics.nodes.backup_summary
```

Verify that the mode is what you intended. If mode is `primary`, the watchdog can be running while automatic failover is disabled.

## 9. Controlled test and rollback

Do not force a node failure when remote SSH/LuCI is your only access path. Perform the test with local recovery available. Confirm:
- Primary healthy -> route stays primary.
- Primary fails three consecutive probes while backup is healthy -> route moves to backup.
- Both nodes fail to threshold -> route may move to `_direct`.
- Primary recovers for three consecutive successful probes -> route returns to primary under the documented policy.
- Xray validation failure rolls back to previous route.
- Restart/reboot returns to the intended mode and service state.

Rollback: stop and disable the watchdog first, then restore the backed-up live scripts and config. Verify route and PassWall2 manually before removing backups. Never restore a sanitized example as if it were the user's original config.
