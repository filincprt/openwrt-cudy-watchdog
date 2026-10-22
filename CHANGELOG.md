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
