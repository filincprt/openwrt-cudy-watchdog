# Current status snapshot

Last update: **2026-10-23**. This is a record of observed output, not a claim that every failure branch has been stress-tested.

## Reference hardware and network

- Router: Cudy WR3000S AX3000 V2.
- Firmware: OpenWrt 25.12.6, revision `r33311-981c978eff`.
- Router LAN address observed: `192.168.50.1`.
- WAN DHCP address observed: `192.168.1.164/24`; gateway `192.168.1.1`. This appears to be double NAT behind an upstream router.
- No IPv6 default route was observed during the earlier audit.
- PassWall2 with Xray is used for node routing.

## Last user-confirmed live state

| Item | Value / status |
|---|---|
| `ha_watchdog.main.mode` | `primary` — current user-selected mode after repeated false failovers; automatic routing is intentionally paused |
| `passwall2.rulenode.default_node` | `PusiSLgE` — primary route confirmed at the same check |
| Watchdog service | Reported `running` in the last service checks |
| Probe timeout | `/usr/bin/timeout -k 2 15` in live core and metrics-only checker |
| Auto loop pause | Random 5–15 seconds after each full cycle |
| Failure threshold | Three consecutive failures for relevant failover decisions |
| Primary recovery threshold | Three consecutive successful primary probes |
| Manual-mode telemetry interval | Random 180–300 seconds after the loop change |
| Auto-mode metric publication gate | Script connected to core and passed shell syntax checks; runtime interval still needs verification |
| Home Assistant metrics | Latest post-guard metrics check (2026-10-23): primary HTTP 204 / RTT 293 ms / `ok=3 fail=0`; backup HTTP 204 / RTT 377 ms / `ok=3 fail=0` |
| Controlled outage test | Pending |

The full cycle time is probe execution plus the pause. Two probes run sequentially; if either times out, the cycle may take longer. Do not equate a 5–15 second pause with a 5–15 second total cycle.

## Live script paths

- Core: `/usr/bin/passwall2-failover-core`
- Wrapper: `/usr/bin/passwall2-failover`
- Loop: `/usr/bin/passwall2-failover-loop`
- Metrics publisher: `/usr/bin/passwall2-watchdog-publish-metrics`
- Publication gate: `/usr/bin/passwall2-watchdog-publish-due`
- Manual-mode metrics probe: `/usr/bin/passwall2-watchdog-probe-metrics`
- procd service: `/etc/init.d/passwall2-failover-watchdog`
- Runtime state: `/tmp/passwall2-failover-state`
- Lock: `/tmp/passwall2-failover.lock`
- Route UCI key: `passwall2.rulenode.default_node`
- Control UCI key: `ha_watchdog.main.mode`

## Telemetry fields and behavior

The UCI section is `ha_watchdog_metrics.nodes`. Published fields include:

- `primary_result` / `backup_result`: raw HTTP-code/seconds result or `no-response`.
- `primary_ok` / `backup_ok`: `online` or `offline`.
- `primary_rtt_ms` / `backup_rtt_ms`: rounded milliseconds or `unknown`.
- `primary_failures` / `backup_failures`: consecutive failure count.
- `primary_checked_at`, `backup_checked_at`, `last_check`: local router timestamps.
- `primary_summary` / `backup_summary`: concise strings shown in Home Assistant.

The publisher uses staged UCI runtime changes and does not commit telemetry to flash every cycle. The values reset to defaults after reboot until a fresh publication. The publisher begins by reverting the previous staged telemetry delta, which was necessary after an earlier accidental accumulation grew `/tmp/.uci/ha_watchdog_metrics` to 48.8 KB. After the fix, the delta was observed at 722 bytes.

### Latest schedule separation change

The core's metrics call was changed from `passwall2-watchdog-publish-metrics` to `passwall2-watchdog-publish-due`. Both core and gate passed `sh -n`; grep confirmed the core calls the gate. The user then selected `auto` and confirmed mode `auto`, route `PusiSLgE`.

**Still needs live verification:** inspect `metrics_last_publish`, `metrics_interval`, `last_check`, and logs across at least two automatic cycles to prove that core probes continue frequently while UCI telemetry updates only every 180–300 seconds. Syntax success alone does not prove the timing behavior.

## Node-ID and safety caveats

The current reference scripts use hard-coded primary ID `PusiSLgE` and backup ID `fAk268mE`; direct routing is `_direct`. These are installation-specific and may change after subscription refresh. A route manually selected in LuCI can be overwritten by the watchdog. Dynamic role resolution is not implemented.

The HTTP 204 probe only proves that the configured test request succeeded through the node at that moment. It does not guarantee all websites work and does not establish whether any particular failure is caused by external blocking.

## Verified observations

- procd service autostart was observed; service reported `running` after reboot.
- A reboot initially showed direct routing and later returned to primary, consistent with three successful primary probes. This was observed recovery, not a controlled outage test.
- Standalone tests returned HTTP 204 for both nodes after timeout was increased to 15 seconds.
- Manual-mode telemetry correctly displayed online/offline, HTTP code, RTT, failures, and timestamp.
- The Home Assistant VPN section displayed primary and backup summaries at the same timestamp.
- Shell syntax checks passed for the live publication gate and core after the latest connection change.

## Next safe steps

1. Read-only verify that `mode=primary`, route and service status are still correct while protection is being prepared.
2. Observe logs across at least two complete cycles and compare the time between health-probe log lines with `last_check` changes.
3. Verify the publication gate's interval files and that health probes are not skipped.
4. Only then record the new cadence as runtime-verified.
5. Plan a controlled outage/recovery test only when local LuCI/SSH access or another recovery path is available.

Related: [Watchdog](WATCHDOG.md), [Home Assistant](HOME-ASSISTANT.md), [Diagnostics](DIAGNOSTICS.md), [Backups](BACKUPS.md).


## Latest confirmed configuration — 2026-10-22, after telemetry throttle

- User selected `Авто` in the existing HA mode helper. Direct UCI checks confirmed `ha_watchdog.main.mode=auto` and route `PusiSLgE`.
- The live loop was changed so manual modes (`primary`, `backup`, `off`) perform metrics-only checks, then wait 180–300 seconds; automatic mode keeps the 5–15 second random pause after each core cycle.
- The core's metrics call was changed from direct publisher invocation to `/usr/bin/passwall2-watchdog-publish-due`. Syntax checks passed for the live throttle helper and core. This preserves frequent health probes in auto mode while staging new telemetry into UCI about every 3–5 minutes.
- The throttle tracks `metrics_last_publish` and `metrics_interval` in `/tmp/passwall2-failover-state`; these are volatile and reset on reboot. First auto-mode run may publish immediately.
- The existing Home Assistant VPN section now shows `input_text.passwall2_primary_metrics` and `input_text.passwall2_backup_metrics`. Latest user-provided dashboard snapshot at 22:37:42 showed both nodes online, HTTP 204, 0 failures, RTT 300 ms primary / 367 ms backup.
- The publisher runs `uci revert ha_watchdog_metrics` before setting current values. A bounded staged delta of 722 bytes was verified previously, avoiding repeated accumulation in `/tmp/.uci/ha_watchdog_metrics`.
- Remaining important risks: node IDs remain hard-coded; no controlled outage/recovery test has been performed; earlier `no-response` results were not conclusively diagnosed; automatic mode probes still run every cycle and jitter does not guarantee protection against server blocking.


## Temporary test-port cache fix — 2026-10-23

Investigated node-test timeouts (exit code 124) while real traffic through the primary route continued to work. Shell tracing showed get_new_port() looping between cached ports 49150 and 49151 after the temporary-test cache filled: /tmp/etc/passwall2/var had 256 get_port_* keys spanning 48900–49151. The diagnostic JSON passed Xray config validation.

Before editing, backups were created for the live test.sh, socks_auto_switch.sh and runtime cache. Added del_cache_var for the allocated temporary port after cleanup in both test scripts; sh -n passed for each. Removed only stale cache keys 48900–49151 and retained unrelated entries 2001–2004. Primary tests returned HTTP 204 twice, backup returned HTTP 204, and the metrics-only check refreshed HA summaries to primary 325 ms / backup 369 ms / zero failures at 2026-10-23 15:58:01. The port-key count remained 4 after tests. The selected mode remains primary; overnight auto stability and controlled failover/recovery remain unverified.


## Post-cleanup stability observation — 2026-10-23 16:10

Read-only router checks after the cache fix showed mode `primary`, route `PusiSLgE`, and watchdog service `running`. The `get_port_*` cache count remained 4. HA summaries at `2026-10-23 16:10:46` showed primary online / HTTP 204 / RTT 313 ms / failures 0 and backup online / HTTP 204 / RTT 337 ms / failures 0.

Logs show both metrics probes returning `no-response` with fail=3 at 15:44 and 15:48 (before the successful post-cleanup run sequence), followed by successful HTTP 204 checks for both nodes at 15:52, 15:56, 16:01, 16:05 and 16:10. This supports the temporary-port cache fix. It is a short observation window, not an overnight or controlled failover/recovery test. Keep mode `primary` until a longer stable window is observed.

Cleanup completed: temporary diagnostic trace, diagnostic JSON and the old cache copy were removed after their diagnostic use. Keep the two `*.bak-before-port-cache-fix` script originals and the ordinary SSH/cron recovery copies until the fix is considered stable. The earlier pending-cleanup note is superseded by this observation.


## Additional guardrail identified before re-enabling auto — 2026-10-23

The temporary-port cache fix currently calls `del_cache_var` on the normal cleanup path in `test.sh` and `socks_auto_switch.sh`. A remaining edge case needs handling: if the outer `/usr/bin/timeout -k 2 15` terminates `test.sh` before normal cleanup, the port-key cleanup line may be skipped. Before re-enabling automatic failover, inspect and add a safe signal/timeout cleanup path (without clearing unrelated cache keys), then validate both normal completion and an intentionally timed-out test. Protection work should then add one confirmation probe after a failed test and a recovery hold-down to reduce route flapping. No such watchdog protection has been deployed yet.


## Protection update — 2026-10-23

The earlier “Additional guardrail” section above records the state before protection was implemented; this section supersedes its pending-work status.

- Live backups were created before the changes: core and metrics probe use `*.bak-before-probe-guard`; PassWall2 `test.sh` and `socks_auto_switch.sh` use `*.bak-before-timeout-cleanup`; the core also has `*.bak-before-cooldown`.
- Live `/usr/share/passwall2/test.sh` now registers cleanup traps after allocating the test port. Cleanup terminates the temporary node-test process, removes its temporary files, and deletes only that probe's `get_port_<port>` cache entry. `sh -n` passed. An intentionally interrupted test returned timeout exit code 124; afterward no matching temporary files were found, and the cache showed only the unrelated `get_port_2001`–`get_port_2004` entries.
- The live core and metrics-only probe now retry once after an unsuccessful probe, waiting 2 seconds. Both passed `sh -n`; the metrics-only checker ran successfully for both nodes: primary `204:0.292797`, backup `204:0.377022`, both `ok=3 fail=0`.
- The core now has a 600-second hold-down before an ordinary return from backup to primary. It bypasses the hold-down after three consecutive backup failures when the primary probe is currently healthy. Syntax passed; this automatic routing branch has **not** been exercised in live failover because the selected mode remains `primary`.
- Current selected route remains `PusiSLgE`; mode remains `primary`. Do not re-enable `auto` yet: retry-on-failure behavior, hold-down branch, long-run stability, and controlled failover/recovery still need safe runtime verification.
