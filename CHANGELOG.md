# Change log

## 2026-10-22 — initial documented snapshot

- Recorded OpenWrt 25.12.6 on Cudy WR3000S AX3000 V2.
- Recorded primary node `PusiSLgE`, backup node `fAk268mE`, direct node `_direct`, watchdog UCI mode/status and service paths.
- Added a `procd` service and loop: `/etc/init.d/passwall2-failover-watchdog` and `/usr/bin/passwall2-failover-loop`.
- Enabled the service; `/etc/rc.d/S99passwall2-failover-watchdog` and `K10...` symlinks were observed.
- Removed the old minute-based watchdog cron line after the service produced repeated successful logs. Kept the daily PassWall2 subscription refresh.
- Wrapped the core's node probe in `/usr/bin/timeout -k 2 10`; `sh -n` passed, and isolated tests for both nodes returned HTTP 204 with exit code 0.
- Added `/usr/bin/geoip.dat` and `/usr/bin/geosite.dat` symlinks to files under `/usr/share/v2ray/`. The relation to the original issue is not proven.
- Verified repeated logs with `ok=3 fail=0` for both nodes and no lock directory after completed cycles.
- Automatic failover under a controlled failure and subsequent recovery has **not** yet been tested.

## 2026-10-22 — boot/autostart check

- Confirmed `procd` watchdog service reported `running` after reboot and boot symlinks were present.
- Found the UCI mode had persisted as `primary`, which bypasses health probes; changed mode to `auto` through the HA helper.
- After switching to `auto`, repeated watchdog logs appeared every roughly 10–11 seconds. Both primary and backup probes returned HTTP `204`, counters showed `ok=3 fail=0`, and the selected route/status were `PusiSLgE` / `primary`.
- Confirmed service boot autostart, but not a simulated outage + recovery sequence.

## 2026-10-22 — documented Auto semantics and node-ID limitation

- Clarified that `ha_watchdog.main.mode=auto` is the watchdog control mode, distinct from PassWall2's native URLTest/auto node group.
- Documented that route recovery currently selects the hard-coded primary ID rather than a native Auto group.
- Recorded that primary/backup IDs are duplicated as literals in the core and wrapper, so LuCI route changes are not adopted automatically and subscription node-ID changes may break assumptions.
- Future improvement: resolve configured primary/backup roles dynamically (with missing/ambiguous-match safeguards) or intentionally redesign around a native PassWall2 URLTest group. No live router scripts were changed in this documentation update.

## 2026-10-22 — documented power-cycle behavior

- Recorded expected boot sequence: enabled procd service starts automatically; the watchdog mode is read from persistent UCI; `/tmp` counters and lock reset on reboot.
- Recorded startup caveat: if mode persists as `primary`, `backup`, or `off`, the wrapper enforces it and skips probes. The mode should be checked after boot; current observed mode is `auto`.
- Noted that early-boot connectivity transients can count as probe failures and that a controlled restart/outage recovery test remains pending.

## 2026-10-22 — reboot recovery observed

- After a manual reboot, the route/status first appeared as direct connection, then switched to the primary node without a manual mode change.
- This is consistent with early-boot node probes failing temporarily and the watchdog returning from `_direct` after three successful primary probes.
- Exact transition logs were not provided, so the result is recorded as an observed behavior consistent with the watchdog logic, not as a full controlled outage test.

## 2026-10-22 — post-recovery state confirmed

- After reboot, route/status initially showed direct connection, then the watchdog returned to primary automatically.
- Follow-up UCI checks confirmed mode `auto` and selected PassWall2 route `PusiSLgE`. The watchdog did not remain pinned in manual `primary` mode.


## 2026-10-22 — jitter and three-failure threshold deployed

- Created router-side backups: `/usr/bin/passwall2-failover-core.bak-before-jitter`, `/usr/bin/passwall2-failover.bak-before-jitter`, and `/usr/bin/passwall2-failover-loop.bak-before-jitter`.
- Changed failover/offline thresholds from 2 to 3 consecutive failed probe cycles in core and wrapper. Recovery remains 3 consecutive successful primary probes.
- Replaced the fixed loop delay with a random 5–15 second pause using BusyBox `$RANDOM`.
- Syntax checks passed for core, wrapper and loop; watchdog service restarted and reported `running`.
- Logs showed some blank probe results and two consecutive cycles where both probes failed. The route did not change at failure count 2, as intended after the threshold increase.
- Later, both probes repeatedly returned HTTP `204`, failure counters reset to zero, current route was `PusiSLgE`, and status was `primary` in mode `auto`.
- User observed an automatic direct-to-primary recovery during this period. A controlled outage/recovery test remains pending.


## 2026-10-22 — metrics telemetry in manual modes

- Added UCI telemetry section `ha_watchdog_metrics.nodes`, publisher script reference, and metrics-only checker reference.
- Added `/usr/bin/passwall2-watchdog-probe-metrics` for manual `primary`, `backup`, and `off` modes. It uses separate `metric_*` counter files and never changes the selected VPN route or automatic decision counters.
- Updated watchdog loop so manual modes publish metrics; automatic mode continues to collect and publish from the core's regular probes. Random 5–15 second pause remains.
- Backups created on router: `passwall2-failover-core.bak-before-metrics-only`, `passwall2-failover.bak-before-metrics-only`, and `passwall2-failover-loop.bak-before-metrics-mode`.
- Validated helper directly: both nodes returned HTTP 204; UCI stored online states, RTT in milliseconds, zero failures, and timestamps. Confirmed the route remained `PusiSLgE` while mode was `primary`.
- Restarted watchdog; service reported `running`. Logs contained repeated `Metrics-only primary/backup` messages approximately 15 seconds apart. HA dashboard display remains unfinished.
