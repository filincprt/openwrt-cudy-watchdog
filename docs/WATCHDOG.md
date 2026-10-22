# PassWall2 failover watchdog

## Live paths

- Core: `/usr/bin/passwall2-failover-core`
- Wrapper: `/usr/bin/passwall2-failover`
- Loop: `/usr/bin/passwall2-failover-loop`
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
    sleep 5
done
```

The 5-second delay is **in addition to** the execution time. Each cycle tests primary then backup sequentially. Observed complete cycle cadence was roughly 17–18 seconds while both probes were healthy.

The old cron entry `* * * * * /usr/bin/passwall2-failover >/dev/null 2>&1` was removed to avoid two schedulers competing for the lock. The daily PassWall2 subscription refresh remains.

## Boot/autostart test

On 2026-10-22, the service was enabled (both `S99...` and `K10...` links existed) and reported `running` after a reboot. However, `ha_watchdog.main.mode` was `primary`, a persisted manual mode. The wrapper correctly forced `PusiSLgE` and exited early, so no periodic probe log was emitted. After setting the HA mode helper to `Авто`, UCI mode was `auto` and logs resumed: both nodes returned HTTP `204`, failure counters stayed at zero, and complete log cycles were roughly 10–11 seconds apart. Thus service autostart is confirmed; automatic failover/recovery after a controlled outage remains untested.

## Probe

The core runs:

```sh
/usr/bin/timeout -k 2 10 /usr/share/passwall2/test.sh url_test_node "$NODE_ID" urltest_node
```

A result beginning with HTTP 2xx/3xx and a colon is considered successful. The PassWall2 test script starts a temporary SOCKS proxy, waits 2 seconds, then runs curl with connect/max-time options. A hard timeout could theoretically leave child processes behind; after timeout events, inspect temporary processes and logs.

Both nodes returned `204` and exit code 0 in isolated tests after the timeout wrapper was added. Syntax check passed. This does not prove the timeout cleanup path under forced hangs.

## Counters / decision logic in core

Counters are capped at 3 and stored in `/tmp/passwall2-failover-state`.

- Current primary: after 2 consecutive primary failures, switch to backup if backup currently probes healthy; switch to direct if backup has also failed at least twice.
- Current backup: return to primary after 3 consecutive primary successes; if backup fails at least twice, prefer a healthy primary; if both have failed at least twice, switch to direct.
- Current direct: return to primary after 3 consecutive primary successes; if primary is not yet at 3 but backup reaches 3 consecutive successes, use backup.
- Unknown current node: prefer a healthy primary, otherwise backup after at least 2 primary failures when backup is healthy, otherwise direct after both have at least 2 failures.

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

## Controlled fail/recovery test — still pending

Do not test a failure remotely unless you have local access to the router. The test should verify primary down -> backup, both down -> direct, and primary restored -> primary. Record timestamps and watchdog logs. Avoid making both nodes unavailable if remote management is your only access.
