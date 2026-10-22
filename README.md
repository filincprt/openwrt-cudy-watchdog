# Cudy WR3000S V2 — OpenWrt / PassWall2 / Watchdog

Private operations notebook for the Cudy router and its Home Assistant integration. Snapshot date: **2026-10-22**.

> This is sanitized documentation, not a complete router backup. It intentionally excludes live credentials, VPN subscription content, the private SSH key, HA long-lived tokens, and the working webhook token.

## Current state (verified from router output)

- Device: Cudy WR3000S AX3000 V2.
- Firmware: OpenWrt 25.12.6, `r33311-981c978eff`.
- LAN address: `192.168.50.1`.
- WAN DHCP address observed: `192.168.1.164/24`; gateway `192.168.1.1` (upstream router/double NAT).
- Primary PassWall2 node ID: `PusiSLgE`.
- Backup node ID: `fAk268mE`.
- Direct node ID: `_direct`.
- Latest verified control mode: `primary` (manual pin); selected route: `PusiSLgE`; HA status last reported as `primary`.
- Watchdog service: `/etc/init.d/passwall2-failover-watchdog`; status was `running` and boot links were present.
- Old once-per-minute watchdog cron entry was removed; daily PassWall2 subscription refresh remains.
- Current loop runs the wrapper, uses a randomized 5–15 second pause, and in manual modes (`primary`, `backup`, `off`) runs a metrics-only probe of both nodes. In `auto`, the core publishes metrics during its regular probes.
- Latest post-restart metrics-only probes returned HTTP `204` for both nodes (primary about 767 ms and backup about 436 ms in the latest logged cycle); failure counters were `0`.
- Core probe command is wrapped in `/usr/bin/timeout -k 2 15`. Shell syntax and isolated probes passed.
- Symlinks were created: `/usr/bin/geoip.dat -> /usr/share/v2ray/geoip.dat` and `/usr/bin/geosite.dat -> /usr/share/v2ray/geosite.dat`. Their relationship to the earlier problem is **not proven**.

## Known limitation to resolve

The watchdog has hard-coded primary/backup IDs (`PusiSLgE` / `fAk268mE`). HA control mode `auto` is distinct from a native PassWall2 URLTest group. Changing the active node in LuCI does not update the script's roles, and subscription refreshes may change node IDs. See [Watchdog](docs/WATCHDOG.md); do not treat the current script as subscription-safe until dynamic role resolution is implemented and tested.

## Documents

- [Status and known configuration](docs/STATUS.md)
- [Watchdog logic and operation](docs/WATCHDOG.md)
- [Home Assistant integration](docs/HOME-ASSISTANT.md)
- [Firewall / SSH audit](docs/FIREWALL.md)
- [Backups and rollback](docs/BACKUPS.md)
- [Read-only diagnostics](docs/DIAGNOSTICS.md)
- [Change log](CHANGELOG.md)
- `scripts/`: reference snapshots and sanitized wrapper template; these are not automatically safe drop-in replacements.

## Safety rules

1. Keep this repository **Private**.
2. Never commit `/etc/config/passwall2`, subscription URLs/content, root passwords, private SSH keys, HA long-lived tokens, or a working webhook URL/token.
3. Compare all reference scripts with the live router files before restoring or deploying them.
4. Do not deliberately disable both VPN nodes remotely unless local router access is available.
5. Do not reset/reflash the router as a first-line recovery step.
6. This repo documents the state we observed. It is not proof that failure/recovery has been stress-tested; that test remains pending.

## Boot/autostart test (2026-10-22)

- The `procd` service was enabled and boot links were present. After a reboot, the service reported `running`.
- The persisted mode was `primary` (manual pin), not `auto`; this made the wrapper force the primary node and exit without running the two health probes. The service being alive therefore did not mean health checks were running.
- After changing the HA mode helper to `Авто`, `ha_watchdog.main.mode` became `auto` and the service resumed tests. Recent log cycles were about 10–11 seconds apart, both nodes returned HTTP `204`, and both failure counters stayed at 0.
- Latest target state: service enabled/running, mode `primary` (manual pin), route `PusiSLgE`. In this manual mode the new metrics-only job is active; it must not change the route. Home Assistant metrics display is still pending, as is a controlled failure/recovery test.

## Current schedule

The old cron line `* * * * * /usr/bin/passwall2-failover >/dev/null 2>&1` was removed on 2026-10-22 after the procd service produced repeated successful probe logs. The daily subscription refresh is still in `/etc/crontabs/root`:

```cron
00 0 * * * setsid lua /usr/share/passwall2/subscribe.lua start sub_WVRAy cron > /dev/null 2>&1 &
```

See [Watchdog](docs/WATCHDOG.md) before changing the schedule.


## Metrics-only telemetry — 2026-10-22

- UCI telemetry section: `ha_watchdog_metrics.nodes` (read-only from HA; values are staged by `uci set` and intentionally not committed on every check to avoid flash writes).
- Publisher: `/usr/bin/passwall2-watchdog-publish-metrics`; manual-mode probe: `/usr/bin/passwall2-watchdog-probe-metrics`.
- Manual-mode probes use separate counter files `metric_p_ok`, `metric_p_fail`, `metric_b_ok`, and `metric_b_fail` under `/tmp/passwall2-failover-state`; they do not modify automatic failover counters or select a route.
- Last confirmed manual-mode check returned HTTP 204 from both nodes, with zero consecutive failures. Home Assistant dashboard entities have not been added yet.


## Latest verification — telemetry and timeout fix (2026-10-22)

- The live timeout in both `/usr/bin/passwall2-failover-core` and `/usr/bin/passwall2-watchdog-probe-metrics` was raised from 10 to 15 seconds. Standalone tests then returned `204:0.365245` (primary) and `204:0.360907` (backup), both with exit code 0. Subsequent watchdog logs at 22:28:49 and 22:29:30 showed both nodes returning HTTP 204 and zero consecutive failures. This supports the timeout adjustment but does not establish the definitive cause of earlier timeouts.
- The publisher now executes `uci revert ha_watchdog_metrics` before staging the current cycle's metric fields. After a manual publish, `/tmp/.uci/ha_watchdog_metrics` was 722 bytes and `uci show ha_watchdog_metrics` succeeded; the earlier accumulated delta was backed up to `/tmp/ha_watchdog_metrics.uci-delta.bak` and reverted.
- Watchdog service reports `running`; latest mode `primary` and route `PusiSLgE` were confirmed. Manual-mode telemetry does not select a route.
- Home Assistant helpers `input_text.passwall2_primary_metrics` and `input_text.passwall2_backup_metrics` now exist; a UI-created polling automation populates them through `openwrt.uci_get`. The Markdown card still needs its final UI formatting confirmed. A controlled outage/recovery test remains pending.
