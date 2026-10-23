# PassWall2 failover watchdog

## Live paths

- Core: `/usr/bin/passwall2-failover-core`
- Wrapper: `/usr/bin/passwall2-failover`
- Loop: `/usr/bin/passwall2-failover-loop`
- Metrics publisher: `/usr/bin/passwall2-watchdog-publish-metrics`
- Manual-mode metrics-only probe: `/usr/bin/passwall2-watchdog-probe-metrics`
- Metrics UCI section: `ha_watchdog_metrics.nodes`
- procd init script: `/etc/init.d/passwall2-failover-watchdog`
- UCI state: `ha_watchdog.main.mode`, `ha_watchdog.main.status`
- PassWall2 route: `passwall2.rulenode.default_node`
- State files: `/tmp/passwall2-failover-state/{p_ok,p_fail,b_ok,b_fail}`
- Lock: `/tmp/passwall2-failover.lock`
- Manual-off marker: `/etc/passwall2-vpn-manual-off`

State and lock files under `/tmp` are volatile and disappear on reboot.

## Scheduler

The persistent procd service is enabled. It starts the loop:

```sh
while :; do
    /usr/bin/passwall2-failover 2>&1 | while IFS= read -r line; do
        logger -t passwall2-watchdog "$line"
    done
    MODE="$(uci -q get ha_watchdog.main.mode 2>/dev/null)"
    case "$MODE" in
        primary|backup|off)
            /usr/bin/passwall2-watchdog-probe-metrics 2>&1 | while IFS= read -r line; do
                logger -t passwall2-watchdog-metrics "$line"
            done
            ;;
    esac
    case "$MODE" in
        primary|backup|off)
            RANDOM_VALUE="$RANDOM"
            WAIT=$((180 + RANDOM_VALUE % 121))
            ;;
        *)
            RANDOM_VALUE="$RANDOM"
            WAIT=$((5 + RANDOM_VALUE % 11))
            ;;
    esac
    logger -t passwall2-watchdog "Next cycle in ${WAIT}s (mode=${MODE:-auto})"
    sleep "$WAIT"
done
```

The 5-second delay is **in addition to** the execution time. Each cycle tests primary then backup sequentially. Observed complete cycle cadence was roughly 17–18 seconds while both probes were healthy.

The old cron entry `* * * * * /usr/bin/passwall2-failover >/dev/null 2>&1` was removed to avoid two schedulers competing for the lock. The daily PassWall2 subscription refresh remains.

## Boot/autostart test

On 2026-10-22, the service was enabled (both `S99...` and `K10...` links existed) and reported `running` after a reboot. However, `ha_watchdog.main.mode` was `primary`, a persisted manual mode. The wrapper correctly forced `PusiSLgE` and exited early, so no periodic probe log was emitted. After setting the HA mode helper to `Авто`, UCI mode was `auto` and logs resumed: both nodes returned HTTP `204`, failure counters stayed at zero, and complete log cycles were roughly 10–11 seconds apart. Thus service autostart is confirmed; automatic failover/recovery after a controlled outage remains untested.

## Probe

The core runs:

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node "$NODE_ID" urltest_node
```

A result beginning with HTTP 2xx/3xx and a colon is considered successful. The PassWall2 test script starts a temporary SOCKS proxy, waits 2 seconds, then runs curl with connect/max-time options. A hard timeout could theoretically leave child processes behind; after timeout events, inspect temporary processes and logs.

Both nodes returned `204` and exit code 0 in isolated tests after the timeout wrapper was added. Syntax check passed. This does not prove the timeout cleanup path under forced hangs.

## Counters / decision logic in core

Counters are capped at 3 and stored in `/tmp/passwall2-failover-state`.

- Current primary: after 3 consecutive primary failures, switch to backup if backup currently probes healthy; switch to direct if backup has also failed at least 3 times.
- Current backup: return to primary after 3 consecutive primary successes; if backup fails at least 3 times, prefer a healthy primary; if both have failed at least 3 times, switch to direct.
- Current direct: return to primary after 3 consecutive primary successes; if primary is not yet at 3 but backup reaches 3 consecutive successes, use backup.
- Unknown current node: prefer a healthy primary, otherwise backup after at least 3 primary failures when backup is healthy, otherwise direct after both have at least 3 failures.

After a route change the script commits UCI, restarts PassWall2, waits 2 seconds and validates the default Xray ACL config. If validation fails, it attempts to restore the previous route and restart PassWall2.

## Important: two different meanings of “Auto”

- `ha_watchdog.main.mode=auto` is the watchdog's control mode. It means the script should probe and make automatic decisions; it should remain `auto` while the active route moves among primary, backup and direct.
- `passwall2.rulenode.default_node` is the selected route target. In this implementation the core switches this field among the hard-coded primary ID, hard-coded backup ID and `_direct`. It does **not** select a PassWall2 native URLTest node/group on recovery.
- `ha_watchdog.main.status` is a reported state such as `primary`, `backup`, `direct` or `offline`; it is not the control mode.

## Hard-coded node IDs and subscription risk

The live core currently declares `PRIMARY="PusiSLgE"` and `BACKUP="fAk268mE"`; the wrapper also uses those literals for manual `primary` and `backup` modes. Therefore changing the active route in LuCI does not update the watchdog's semantic primary/backup roles; in `auto` mode an unfamiliar current ID falls into the default branch and can be replaced by the hard-coded primary if its probe is healthy. A subscription refresh may recreate nodes with different internal UCI IDs, so a static ID must not be assumed permanent.

Before changing the design, inspect the actual installed `/etc/config/passwall2` node sections and remarks. A safer future design should resolve role IDs from configurable stable node remarks or a configured PassWall2 URLTest group, log missing/ambiguous matches, and fail safe instead of forcing a stale ID. Exact-remark resolution depends on those remarks remaining stable. A native URLTest group is a different policy: PassWall2 chooses among its members and may not always select the preferred primary.

## Mode handling in wrapper

- `auto`: removes the manual-off marker and runs core.
- `primary`: forces `PusiSLgE`.
- `backup`: forces `fAk268mE`.
- `off`: creates `/etc/passwall2-vpn-manual-off` and forces `_direct`.

The wrapper updates `ha_watchdog.main.status` and calls the Home Assistant webhook only when status changes. The live webhook token is intentionally **not** stored here. The repository wrapper file is a sanitized template, not a drop-in replacement.

## Useful checks

```sh
/etc/init.d/passwall2-failover-watchdog status
logread | grep 'passwall2-watchdog' | tail -n 40
logread | grep -Ei 'passwall2-failover|failover' | tail -n 80
ps w | grep -E '[p]asswall2-failover-loop|[p]asswall2-failover-core'
ls -ld /tmp/passwall2-failover.lock 2>&1
for f in /tmp/passwall2-failover-state/*; do echo "--- $f"; cat "$f"; done
uci -q get ha_watchdog.main.mode
uci -q get ha_watchdog.main.status
uci -q get passwall2.rulenode.default_node
```

## Expected behavior after power loss / router reboot

- The procd service is enabled at boot (verified links include `S99passwall2-failover-watchdog`). Scripts and UCI configuration persist across power loss; `/tmp/passwall2-failover-state` counters and the lock directory are volatile and reset on reboot.
- Last observed persisted `ha_watchdog.main.mode` was `auto`, and route was `PusiSLgE`. In `auto`, once the loop is running it probes primary and backup. When both pass, it leaves the current route alone.
- During early boot the uplink or proxy stack may not yet be ready. Transient failed probes can trigger the same failover thresholds as real outages; when primary then succeeds 3 times consecutively, current logic returns to the hard-coded primary ID.
- If the persisted mode is instead `primary`, `backup`, or `off`, the wrapper enforces that choice and exits early without health probing. So after a reboot, check the saved mode as well as service status.
- Home Assistant is not required for the core loop to probe/switch, but its selected mode helper and startup automation can potentially change the UCI mode; verify both if they disagree.

## Reboot recovery observation — 2026-10-22

The user rebooted the router. The displayed status initially showed direct connection, then later moved to the primary node automatically. This matches current logic: while current route is `_direct`, three consecutive successful primary probes trigger a switch to `PusiSLgE`. The exact event logs for the transition were not captured, so this is consistent with, rather than a packet-level proof of, the code path. A controlled outage test (primary down, fallback behavior, restore) is still pending.

## Final post-reboot check

A follow-up UCI check after the router reboot/recovery returned `ha_watchdog.main.mode=auto` and `passwall2.rulenode.default_node=PusiSLgE`. The route switched from direct to the primary node automatically and the watchdog remained in auto control mode.

## Tuning update (2026-10-22)

The live scripts were edited and checked:
- Failure comparisons in core and wrapper were changed from two failures to three.
- Recovery remains at three consecutive successes.
- The loop now waits a random 5–15 seconds after each complete test cycle, using BusyBox `$RANDOM`. Cycle time is probe runtime plus this delay; it is not a 5–15 second total cycle.
- Backups are stored on router as `passwall2-failover-core.bak-before-jitter`, `passwall2-failover.bak-before-jitter`, and `passwall2-failover-loop.bak-before-jitter`.
- Syntax checks passed; service was restarted and status returned `running`.
- Two recent cycles showed blank outputs for both probes, with failure count increasing to 2; route did not switch at count 2. Later both probes returned HTTP 204 and counters reset to zero. The user observed an automatic route recovery from direct to primary.
- The underlying cause of blank probes is unknown, so the tuning reduces sensitivity but does not diagnose that condition.

## Controlled fail/recovery test — still pending

Do not test a failure remotely unless you have local access to the router. The test should verify primary down -> backup, both down -> direct, and primary restored -> primary. Record timestamps and watchdog logs. Avoid making both nodes unavailable if remote management is your only access.


## Probe frequency and traffic-triggered monitoring — design discussion (2026-10-22)

Current observed cadence is around 10–11 seconds per completed two-node cycle. Each node probe invokes PassWall2 `test.sh url_test_node`, which starts a temporary SOCKS proxy, waits about 2 seconds, and makes an HTTPS HEAD request to the configured URL (default shown in the script: `https://www.google.com/generate_204`). A steady 10.5-second cadence is approximately 8,200 probe attempts per node per day. Payload is small, but the fixed request pattern and repeated temporary-proxy startup are not free. Xray's official Observatory documentation also warns that fixed-interval probes can create a behavioral fingerprint: https://xtls.github.io/en/config/observatory.html. This is a general caution, not evidence that current checks caused any specific server block.

### Traffic-aware proposal: pros and cons

**Potential benefits**
- Extra tests can be triggered quickly when an active user request or connection appears to stall.
- A slower baseline schedule can reduce periodic requests while retaining autonomous health monitoring.
- A second confirmation probe can help distinguish a transient timeout from a real outage.

**Limitations**
- No user traffic is normal when the home is idle; absence of bytes alone must not be treated as a dead node.
- Ordinary router/WAN counters are not necessarily per-node counters and include direct, DNS, HA and other traffic.
- TCP retransmissions or stalled sessions may continue incrementing counters even when the destination is unusable.
- A traffic-triggered-only monitor may discover an outage only when the next user tries to use the internet, and cannot pre-validate the backup while idle.
- Current implementation tests both configured node IDs independently, even if the active route is direct or backup. A passive traffic monitor does not inherently provide this comparison.

### Recommended direction (not yet implemented)

Use a hybrid design rather than traffic-only detection:
1. Keep a low-rate independent probe for both nodes so the backup is pre-checked.
2. If an actual request/active-traffic symptom indicates trouble, trigger an extra confirmation probe; do not fail over solely because the byte counter stopped increasing.
3. Consider 3 consecutive failures rather than 2 before declaring a node dead, and investigate multi-target verification / startup grace to avoid false direct mode during WAN startup. Increasing the failure threshold delays real failover, so tune only after observing logs.
4. Keep 3 consecutive successful probes to recover; add a short cooldown/minimum-dwell period only if logs show flapping.
5. Do not implement changes until the signal is well-defined and the test scenario can be tested without losing remote access.

## Jitter and failure threshold change — 2026-10-22

Live router change completed and syntax-checked:
- In core and wrapper, failover/offline decision comparisons previously using `-ge 2` were changed to `-ge 3`. Three consecutive failed probe cycles are now required before failover decisions that use these counters. Recovery stays at three consecutive successes.
- The loop's fixed `sleep 5` was replaced with `RANDOM_VALUE="$RANDOM"; WAIT=$((5 + RANDOM_VALUE % 11)); sleep "$WAIT"`, giving a 5–15 second random pause **after** each completed cycle.
- The procd service was restarted and reported `running`. `sh -n` passed for core, wrapper and loop.
- Recent observed cycle timestamps included 19:53:20, 19:53:41, 19:54:04, 19:54:17, 19:54:31, 19:54:53, 19:55:07, 19:55:31, 19:55:53, 19:56:07, 19:56:26, 19:56:48 and 19:57:12. This is consistent with variable intervals; total cycle time is probe execution + randomized sleep.
- Earlier both probes returned empty results at 19:43:42, 19:45:19 and 19:45:49. After threshold change, the logged pair of failures reached 2 without triggering a route change. Subsequent cycles returned HTTP 204 for both nodes; current observed counters `p_fail=0`, `b_fail=0`, route `PusiSLgE`, status `primary`, and mode was `auto` (mode line appeared interleaved in terminal paste but output value was `auto`).
- The user also observed one automatic change from direct route back to primary during this period. That matches the intended recovery logic, but the exact route-change timestamps were not captured in the shared log.
- The jitter changes probe scheduling predictability; they do not prove avoidance of external detection. The blank probe outputs still need root-cause investigation if they recur.

No router code was changed as part of the earlier design discussion; the above is the subsequent live change recorded after implementation.


## Metrics-only telemetry (2026-10-22)

Automatic mode keeps the existing core probes and calls the metrics publisher after the core has updated its decision counters. In manual `primary`, `backup`, and `off` modes, the wrapper exits early, so the loop now separately invokes `/usr/bin/passwall2-watchdog-probe-metrics` after the wrapper returns. This script probes both configured nodes, updates the telemetry UCI values, and uses separate `metric_*` counters; it does not edit `passwall2.rulenode.default_node`, restart PassWall2, or modify the core's `p_ok/p_fail/b_ok/b_fail` decision counters.

The publisher writes UCI staged values without committing the metrics config to flash on every cycle. HA reads `ha_watchdog_metrics.nodes`: `primary_result` / `backup_result` (raw HTTP-code:seconds output or `no-response`), `*_ok` (`online`/`offline`), `*_rtt_ms`, `*_failures`, `*_checked_at`, and `last_check`. These values are volatile and are reset after reboot until new checks run. Last validation in manual `primary` mode showed service `running`, both probes returning HTTP 204, and the selected route unchanged at `PusiSLgE`.


## Telemetry throttling change — 2026-10-22

The user asked to reduce repeated test traffic while preserving automatic failover. The intended split is:

- In `auto`, the core continues probing primary and backup every full cycle and uses its existing counters/state machine. The core's metrics call now targets `/usr/bin/passwall2-watchdog-publish-due`, which should invoke the publisher only when the 180–300 second interval is due.
- In manual `primary`, `backup`, or `off`, the wrapper exits before the core. The loop therefore calls `/usr/bin/passwall2-watchdog-probe-metrics` separately, then waits a random 180–300 seconds.
- The auto loop pause remains random 5–15 seconds after each full cycle. Probe runtime is additional.
- The gate stores its last publication epoch and interval under `/tmp/passwall2-failover-state/metrics_last_publish` and `metrics_interval`. These files reset on reboot.

After installation, `sh -n` passed for the gate and core, and grep confirmed the core calls `publish-due`. The user selected `auto`; direct UCI checks confirmed `MODE=auto` and route `PusiSLgE`.

**Runtime verification is still required.** Check at least two cycles: core probe logs should continue at the ordinary cadence, while `ha_watchdog_metrics.nodes.last_check` changes only when the publication gate opens. Syntax checks alone do not prove timing behavior.

Read-only checks:

```sh
echo "MODE=$(uci -q get ha_watchdog.main.mode)"
echo "ROUTE=$(uci -q get passwall2.rulenode.default_node)"
/etc/init.d/passwall2-failover-watchdog status
cat /tmp/passwall2-failover-state/metrics_last_publish 2>/dev/null
cat /tmp/passwall2-failover-state/metrics_interval 2>/dev/null
uci -q get ha_watchdog_metrics.nodes.last_check
logread -e passwall2-watchdog | tail -n 40
```

If `last_check` changes on every core cycle, inspect the gate/publisher call chain before making further changes. If core probe logs stop or the loop is stuck, prioritize restoring the last known-good core backup and validating the service.


## Telemetry throttle — live change on 2026-10-22

The live core now calls `/usr/bin/passwall2-watchdog-publish-due` instead of invoking the publisher on every automatic cycle. This helper keeps the last-publication timestamp and a randomized interval (180–300 seconds) in `/tmp/passwall2-failover-state/metrics_last_publish` and `metrics_interval`.

- In `auto`, both node probes and failover decisions still run each core cycle (probe runtime plus a randomized 5–15 second loop pause). Only publishing the metrics into UCI is throttled to about every 3–5 minutes.
- In manual `primary`, `backup`, and `off`, the wrapper does not run the core; the loop runs the separate metrics-only probe, then waits a randomized 180–300 seconds.
- The live core and metrics-only probe use `timeout -k 2 15`.
- The publisher calls `uci revert ha_watchdog_metrics` before staging a fresh set of values. This prevents an ever-growing `/tmp/.uci/ha_watchdog_metrics` delta. Metrics are intentionally not committed to flash on every update.
- The live dashboard now displays the two summary strings in the existing VPN section. Last user-provided snapshot: primary online / HTTP 204 / RTT 300 ms / failures 0; backup online / HTTP 204 / RTT 367 ms / failures 0; timestamp `2026-10-22 22:37:42`.

This reduces periodic metric publication, but it does **not** reduce automatic-mode health-probe frequency. It also does not guarantee avoidance of filtering or server blocking.


## Temporary test-port cache exhaustion fix — 2026-10-23

The node test timed out with exit code 124 although primary-route traffic worked. Trace showed get_new_port() cycling between cached ports 49150 and 49151. The runtime cache had 256 get_port_* entries spanning 48900–49151; a generated diagnostic JSON passed Xray config validation.

Backups were made before changes. The live /usr/share/passwall2/test.sh and /usr/share/passwall2/socks_auto_switch.sh now call del_cache_var for the allocated temporary test port after removing temporary test artifacts. Both passed sh -n. Stale keys in 48900–49151 were removed while unrelated keys 2001–2004 remained; the runtime cache was backed up before cleanup. Post-fix primary tests returned HTTP 204 (about 358/349 ms), the backup returned HTTP 204 (about 291 ms), and metrics refreshed HA to primary HTTP 204 / RTT 325 ms / failures 0 and backup HTTP 204 / RTT 369 ms / failures 0 at 2026-10-23 15:58:01. Key count remained 4 after tests.

This strongly supports cache exhaustion as the cause of prior timeouts but does not yet prove long-run auto stability. Keep mode primary until stability is observed; the controlled outage/recovery test remains pending.
