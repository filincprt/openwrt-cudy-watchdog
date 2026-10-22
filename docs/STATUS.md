# Current status snapshot

Snapshot date: 2026-10-22. Based on command output in the troubleshooting session. This document should be updated after meaningful changes.

## Device / addressing

- Router model: Cudy WR3000S AX3000 V2.
- Firmware: OpenWrt 25.12.6, revision `r33311-981c978eff`.
- LAN: `192.168.50.1`.
- WAN: DHCP, observed `192.168.1.164/24`.
- Upstream gateway: `192.168.1.1`.
- WAN IPv6 interface `wan6` was down/pending and there was no IPv6 default route at the time of audit.
- Topology appears to be a router behind an upstream router (double NAT).

## PassWall2 / watchdog

| Item | Value |
|---|---|
| Primary node ID | `PusiSLgE` |
| Backup node ID | `fAk268mE` |
| Direct node ID | `_direct` |
| Node UCI setting | `passwall2.rulenode.default_node` |
| Watchdog UCI section | `ha_watchdog.main` |
| Mode | `auto` |
| Last observed route | `PusiSLgE` |
| Last observed HA status | `primary` |
| Core script | `/usr/bin/passwall2-failover-core` |
| Wrapper | `/usr/bin/passwall2-failover` |
| Loop | `/usr/bin/passwall2-failover-loop` |
| procd init script | `/etc/init.d/passwall2-failover-watchdog` |
| State dir (volatile) | `/tmp/passwall2-failover-state` |
| Lock dir | `/tmp/passwall2-failover.lock` |

The service reported `running`, and boot links `S99passwall2-failover-watchdog` and `K10passwall2-failover-watchdog` were present.

## Latest observed probe results

- Primary: `204:0.320248` (example recent result); success counter capped at 3; failure counter 0.
- Backup: `204:0.332126` (example recent result); success counter capped at 3; failure counter 0.
- Logs appeared about 17–18 seconds apart for a full pair of tests.
- The normal HTTP probe target is configured via PassWall2's `url_test_url` setting, default shown by script as `https://www.google.com/generate_204`.

## Boot/autostart verification — 2026-10-22

- `/etc/rc.d/S99passwall2-failover-watchdog` and `K10...` links were present; after reboot the service reported `running`.
- The mode persisted as `primary`, so the service's wrapper forced the primary route and skipped health probes. This was expected manual-mode behavior, not proof of a failed autostart.
- After the mode helper was changed to `Авто`, UCI reported `auto`, route `PusiSLgE`, status `primary`, and recent log lines showed both probes returning HTTP `204` with `ok=3 fail=0` and `p_fail=b_fail=0`.
- Recent full cycle output times were roughly 10–11 seconds apart.

## Important uncertainty

A controlled test where both endpoints fail and then recover has not been done. Successful manual probes and repeated healthy logs do not by themselves prove every failure/recovery branch works. Test only while local access to LuCI or SSH is available.

## Related docs

- [Watchdog](WATCHDOG.md)
- [Firewall](FIREWALL.md)
- [Home Assistant](HOME-ASSISTANT.md)
- [Backups](BACKUPS.md)
