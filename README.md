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
- Watchdog UCI mode: `auto`; selected route: `PusiSLgE`; HA status: `primary`.
- Watchdog service: `/etc/init.d/passwall2-failover-watchdog`; status was `running` and boot links were present.
- Old once-per-minute watchdog cron entry was removed; daily PassWall2 subscription refresh remains.
- Current loop runs the wrapper then sleeps 5 seconds. Full observed cycle cadence was about 17–18 seconds because both node probes are sequential.
- Last observed probes for primary and backup returned HTTP `204`; their counters were `ok=3 fail=0`.
- Core probe command is wrapped in `/usr/bin/timeout -k 2 10`. Shell syntax and isolated probes passed.
- Symlinks were created: `/usr/bin/geoip.dat -> /usr/share/v2ray/geoip.dat` and `/usr/bin/geosite.dat -> /usr/share/v2ray/geosite.dat`. Their relationship to the earlier problem is **not proven**.

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
- Current target state: service enabled/running, mode `auto`, route `PusiSLgE`, status `primary`. Automatic failure/recovery stress test is still pending.

## Current schedule

The old cron line `* * * * * /usr/bin/passwall2-failover >/dev/null 2>&1` was removed on 2026-10-22 after the procd service produced repeated successful probe logs. The daily subscription refresh is still in `/etc/crontabs/root`:

```cron
00 0 * * * setsid lua /usr/share/passwall2/subscribe.lua start sub_WVRAy cron > /dev/null 2>&1 &
```

See [Watchdog](docs/WATCHDOG.md) before changing the schedule.
