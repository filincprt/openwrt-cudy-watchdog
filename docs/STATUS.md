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
| Mode | `primary` (latest confirmed; manual pin) |
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

- The latest metrics-only test showed primary `204:0.353328` and backup `204:0.352807`; both were online with 0 consecutive failures.
- Another cycle showed primary `204:0.373957` and backup `204:0.323430`, again with 0 failures.
- Manual-mode metrics logs were observed about 15 seconds apart in this short sample.
- The normal HTTP probe target is configured via PassWall2's `url_test_url` setting, default shown by script as `https://www.google.com/generate_204`.

## Boot/autostart verification — 2026-10-22

- `/etc/rc.d/S99passwall2-failover-watchdog` and `K10...` links were present; after reboot the service reported `running`.
- The mode persisted as `primary`, so the service's wrapper forced the primary route and skipped health probes. This was expected manual-mode behavior, not proof of a failed autostart.
- The user subsequently selected the manual `primary` mode. The wrapper pins the primary route; telemetry was initially absent because manual branches exit before the core.

## Design caveat — node IDs are hard-coded

The live scripts use `PusiSLgE` as primary and `fAk268mE` as backup in both core and wrapper. HA mode `auto` means the watchdog is enabled; it does not mean PassWall2's currently selected route is a native URLTest/auto group. On recovery, current logic selects the hard-coded primary node ID. Manually selecting a different node in LuCI can be overridden by the next watchdog cycle. Subscription refreshes may alter internal node IDs; the current watchdog is not yet dynamic-role/subscription-safe.

## Reboot recovery observation — 2026-10-22

After a manual reboot, the displayed route initially showed direct connection and later switched to the primary node without a manual mode change. This is consistent with the watchdog holding direct while early-boot probes fail, then returning to the hard-coded primary after 3 consecutive successful primary probes. This was an observed recovery, though exact timestamps/logs from that specific transition were not captured in the message. It is useful evidence that recovery works in practice, but not a full controlled outage test.

## Final post-reboot check

After the observed automatic recovery, a direct UCI check returned `ha_watchdog.main.mode=auto` and `passwall2.rulenode.default_node=PusiSLgE`. This confirms the watchdog control mode remained automatic while the primary route was restored.

## Jitter/threshold update — 2026-10-22

- Core and wrapper failure thresholds using `-ge 2` were changed to `-ge 3`; recovery threshold remains 3 consecutive successes.
- Loop delay now uses BusyBox `$RANDOM` for `5 + RANDOM % 11` seconds after each full core cycle (5–15s random pause). Syntax checks for core, wrapper and loop passed, and the service was restarted and reported `running`.
- Logs after the change showed irregular cycle starts about 14–24 seconds apart. There were a few blank probe results, including two consecutive paired failures, but no failover at failure count 2. Later both nodes repeatedly returned HTTP `204`, with both failure counters at 0 and route `PusiSLgE`.
- User observed one automatic return from direct to primary during this period. A controlled repeatable outage test has not been performed.

## Latest watchdog tuning (2026-10-22)

- Failure thresholds in core and wrapper are now 3 consecutive failed probe cycles (previously 2). The successful recovery threshold remains 3.
- The watchdog loop uses BusyBox RANDOM to add a 5–15 second pause after each full cycle. Syntax checks passed for core, wrapper and loop; service status was running after restart.
- Log times after the change were irregular, roughly 14–24 seconds apart. Some tests produced blank results for both nodes, with two consecutive paired failures, but the route remained on primary at failure count 2.
- Later, repeated probes returned HTTP 204 for both nodes, both failure counters were 0, route was PusiSLgE, status primary, and mode auto. The user observed one automatic route recovery from direct to primary.
- Root cause of the blank probe results is still unknown; controlled outage/recovery testing is pending.

## Important uncertainty

A controlled test where both endpoints fail and then recover has not been done. Successful manual probes and repeated healthy logs do not by themselves prove every failure/recovery branch works. Test only while local access to LuCI or SSH is available.

## Related docs

- [Watchdog](WATCHDOG.md)
- [Firewall](FIREWALL.md)
- [Home Assistant](HOME-ASSISTANT.md)
- [Backups](BACKUPS.md)


## Metrics-only telemetry — 2026-10-22

- Created `/etc/config/ha_watchdog_metrics` with UCI section `ha_watchdog_metrics.nodes` and fields `primary_result`, `primary_ok`, `primary_failures`, `primary_rtt_ms`, `primary_checked_at`, matching backup fields, and `last_check`.
- Publisher script: `/usr/bin/passwall2-watchdog-publish-metrics`. It translates a PassWall2 result such as `204:0.353328` to online state, HTTP result, rounded latency in milliseconds, consecutive failure count, and timestamp. It uses UCI staged changes without `uci commit` to avoid continuous flash writes.
- Added `/usr/bin/passwall2-watchdog-probe-metrics` for manual modes. It uses separate counter files prefixed `metric_` and never changes the selected PassWall2 route.
- Updated the watchdog loop: in `primary`, `backup`, or `off`, it runs the metrics-only checker after the wrapper; in `auto`, the core's existing probe/publish path remains responsible for metrics. The randomized 5–15 second pause remains.
- Validation: publisher produced `primary_ok=online`, `backup_ok=online`, RTT `392`/`438` ms in a manual test; subsequent automated logs showed both nodes returning HTTP `204`, with counters 0. `/etc/init.d/passwall2-failover-watchdog status` returned `running` after restart.
- Latest observed UCI: mode `primary`, route `PusiSLgE`. Home Assistant dashboard entity creation is still pending. Metrics values are not committed to flash each cycle, so the live values are volatile and reset to configured defaults after reboot until the next check.
