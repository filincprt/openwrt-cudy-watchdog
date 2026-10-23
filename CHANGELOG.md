# Change log

## 2026-10-23 — dynamic primary ID after subscription refresh

- Added `scripts/passwall2-failover-resolve-primary.sh`: resolve the current primary from exactly one imported node with `add_mode=2` and `group=stealthsurf`; fail closed on zero or ambiguous matches.
- Updated the core, metrics-only probe and sanitized wrapper template to use the resolver rather than hard-code the primary ID. The backup ID remains fixed at `fAk268mE`.
- Live primary ID changed from `PusiSLgE` to `4m4hltgt` (Finland), then `tLUhZHkw` (Netherlands) after subscription refreshes. The resolver tracked the changes.
- In `auto`, both nodes returned HTTP 204 and the watchdog logged the natural post-cooldown route change from backup to `tLUhZHkw` at 20:50:59 on 2026-10-23. User reports YouTube appears to load better via Netherlands; no numeric post-change speed was recorded.
- A deliberately controlled outage/recovery test remains pending.

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


## 2026-10-22 — telemetry throttling and documentation refresh

- Added `passwall2-watchdog-publish-due.sh` reference. In automatic mode it allows telemetry UCI publication about every randomized 180–300 seconds while core health probes and failover decisions continue on every cycle.
- Updated the loop reference: manual `primary`, `backup`, and `off` modes run the metrics-only probe every randomized 180–300 seconds; automatic mode retains the randomized 5–15 second pause after each completed core cycle.
- Updated the core and manual metrics-only reference timeout from 10 to 15 seconds and changed the core's telemetry call to the throttle helper.
- Added a reusable publisher reference with `uci revert ha_watchdog_metrics` before staging a fresh snapshot. Frequent metrics updates are not committed to flash.
- Rewrote README as the project overview and linked deployment, troubleshooting, HA and AI handoff documents. Added `docs/DEPLOYMENT.md` and `docs/AI-PROMPT.md`.
- Recorded that HA summaries are visible in the existing VPN dashboard and that current control mode was changed to `auto`; route was `PusiSLgE`.
- This is a documentation/reference sync. Live route behavior and failover correctness still require a controlled outage/recovery test with local access available.


## 2026-10-22 — documentation consolidation and AI handoff

- Rewrote `README.md` as the project overview with capabilities, current reference state, limitations, safety rules, and source-of-truth policy.
- Added/verified `docs/DEPLOYMENT.md` for adapting the watchdog with or without Home Assistant, with staged backups, checks, service setup, scheduling, and rollback guidance. `docs/INSTALL.md` now points to the canonical deployment guide to avoid two competing instructions.
- Added `docs/AI-PROMPT.md` with explicit instructions for future AI assistants to read project context, separate observed facts from assumptions, preserve secrets, back up scripts, and update documentation.
- Updated `docs/STATUS.md`, `docs/WATCHDOG.md`, `docs/HOME-ASSISTANT.md`, `docs/BACKUPS.md`, and `docs/DIAGNOSTICS.md` with the latest mode, telemetry dashboard confirmation, gate status, verification gaps, and safe diagnostic commands.
- Synced the core and loop reference snapshots to the 15-second probe timeout, gated auto-mode metric publication, and 180–300 second manual-mode interval.
- User-confirmed current UCI mode is `auto`; selected route is `PusiSLgE`. The gate/core passed shell syntax checks. Actual runtime separation between frequent health checks and slower telemetry publication still needs confirmation in logs; controlled outage/recovery test remains pending.


## 2026-10-22 — Russian documentation

- Added `README.ru.md` and a Russian documentation set under `docs/ru/` covering deployment, status, watchdog behavior, Home Assistant, diagnostics, backups/rollback, firewall/SSH, and AI handoff guidance.
- Linked the Russian version from the top of the English README. Existing English files and paths remain available.
- Kept commands, paths, UCI keys and node IDs unchanged in the translations so they remain copyable. Russian documentation is a translation/reference layer; live router state must still be rechecked before making changes.


## 2026-10-23 — PassWall2 temporary test-port cache fix

- Investigated test timeout exit code 124 while actual primary-route traffic still worked.
- Trace found get_new_port() looping over cached ports 49150/49151 when the temporary-test cache was exhausted (256 keys for 48900–49151). Xray accepted the generated diagnostic JSON.
- Backed up live test.sh, socks_auto_switch.sh and the runtime cache before changing anything.
- Added cleanup of the allocated temporary-port cache key to both scripts; both passed sh -n. Removed only stale cache keys 48900–49151, preserving other keys.
- Post-fix primary and backup probes returned HTTP 204; HA summaries showed both online with zero failures and RTT 325/369 ms. Port-key count remained four.
- Mode remains primary. Long-run auto stability and controlled failover/recovery are not yet verified.


## 2026-10-23 — post-fix verification and diagnostic cleanup

- With mode set to `primary`, watchdog reported `running` and route remained `PusiSLgE`.
- Logs showed both-node test timeouts before cleanup at 15:44 and 15:48, followed by successful HTTP 204 probes for both nodes at 15:52, 15:56, 16:01, 16:05 and 16:10.
- HA telemetry at 16:10:46 showed primary RTT 313 ms and backup RTT 337 ms, both online with zero failures. Runtime port-cache count stayed at 4.
- Removed temporary trace / diagnostic JSON and the stale runtime cache backup after use. Kept the original pre-fix test scripts and important SSH/cron recovery copies.
- Auto mode remains unverified after the fix; long-duration monitoring and controlled failover/recovery are still pending.


## 2026-10-23 — interrupted-test cleanup and failover guardrails

- Added signal/exit cleanup to the live PassWall2 `test.sh` for the allocated temporary port, associated process, and test files. An intentionally interrupted probe returned timeout code 124; afterwards no matching temporary files remained and only unrelated port-cache keys 2001–2004 were observed.
- Added one retry after a failed probe, with a 2-second pause, to the reference failover core and metrics-only probe.
- Added a 600-second hold-down for ordinary backup-to-primary recovery; the core bypasses it after three consecutive backup failures when the primary is currently healthy.
- Shell syntax checks passed for all changed live watchdog scripts. Metrics-only tests returned HTTP 204 for both nodes (primary about 293 ms, backup about 377 ms), each with `ok=3 fail=0`.
- Current mode remains `primary` and route `PusiSLgE`. Automatic routing branches, long-run stability, and a controlled outage/recovery test are still not verified. Keep `auto` disabled for now.
