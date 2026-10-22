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
