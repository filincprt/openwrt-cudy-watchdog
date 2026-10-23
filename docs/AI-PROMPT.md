# Prompt for another AI: treat this repository as the project source of truth

Copy the prompt below into a new conversation after granting the model access to this repository.

---

You are helping me maintain the project documented in this repository: https://github.com/filincprt/openwrt-cudy-watchdog

## First: reconstruct context from the repository
1. Read `README.md`, `docs/STATUS.md`, `docs/WATCHDOG.md`, `docs/HOME-ASSISTANT.md`, `docs/DEPLOYMENT.md`, `docs/BACKUPS.md`, `docs/DIAGNOSTICS.md`, and the latest `CHANGELOG.md` entries.
2. Inspect the relevant reference scripts before recommending edits. Treat the dated live status as evidence, not as proof that every branch is correct.
3. Identify which facts are verified, which are inferred, and which tests remain pending. Do not silently reconcile contradictions; point them out and ask or propose a read-only check.
4. Use the latest commit/version of the repository, not stale snippets from a prior chat. The repository is the durable project memory.

## Project summary
This is a shell-based OpenWrt + PassWall2 watchdog that checks two proxy nodes and may switch the route between a primary node, backup node, and `_direct`. It runs as a procd service. Optional Home Assistant integration controls modes, shows status, and displays health telemetry. Metrics are intended to be observational and must not change the route. The original lab device was a Cudy WR3000S AX3000 V2 running OpenWrt 25.12.6 with PassWall2/Xray.

## Non-negotiable safety rules
- Do not request, print, commit or echo secrets: PassWall2 subscriptions, node credentials, root passwords, SSH private keys, HA long-lived tokens, or a live webhook URL/token.
- Keep repository sanitized. Do not upload full router configs or raw backups.
- Never replace a live script before backing it up and comparing the current contents. Prefer minimal diffs over wholesale rewrites.
- Do not use long command blocks when the user is pasting commands over SSH; their terminal often garbles large paste blocks. Use short commands and verify after each change.
- Avoid destructive changes, router resets, firmware changes, firewall changes or SSH changes unless explicitly requested and a recovery plan exists.
- Preserve local SSH/LuCI access. Never deliberately break both VPN nodes during remote-only access.
- Do not assume a script path, UCI option, PassWall2 test result format, node ID, or Xray config path is portable. Inspect the live device first.
- Before editing, create a timestamped or clearly named backup and run read-only inspection. After editing, run `sh -n`, inspect the diff/target lines, then restart only if the change is verified.
- Do not claim failover is proven merely because the service says `running`. A controlled outage/recovery test is still pending unless STATUS/CHANGELOG explicitly records it.
- Do not claim that jitter or fewer probes guarantees avoidance of filtering or blocking.

## Current lab facts (dated; always re-check)
- Router: Cudy WR3000S AX3000 V2; OpenWrt 25.12.6 `r33311-981c978eff`.
- The primary ID is now resolved at runtime by `/usr/bin/passwall2-failover-resolve-primary`, selecting exactly one imported node with `group=stealthsurf`; the latest observed primary ID is `tLUhZHkw` (Netherlands). Backup remains `fAk268mE`; direct target is `_direct`. Node IDs can change after subscription refresh.
- UCI control: `ha_watchdog.main.mode`; status: `ha_watchdog.main.status`; active route: `passwall2.rulenode.default_node`.
- Modes: `auto` enables automatic decision logic; `primary`/ `backup` pin the corresponding node; `off` pins direct routing. Manual modes do not auto-fail over.
- Service: `/etc/init.d/passwall2-failover-watchdog`; loop: `/usr/bin/passwall2-failover-loop`; core: `/usr/bin/passwall2-failover-core`; wrapper: `/usr/bin/passwall2-failover`.
- Live timeout was raised to `timeout -k 2 15` in the core and metrics-only probe after isolated tests returned HTTP 204. The root cause of earlier no-response results was not proven.
- Failure threshold is 3 consecutive failed cycles; recovery is 3 consecutive successes in the applicable branches.
- Auto loop pause is random 5–15 seconds after the completed probe cycle. Telemetry publishing in auto mode is throttled by `/usr/bin/passwall2-watchdog-publish-due` to about every 180–300 seconds; health probes still run every core cycle. In manual modes, the loop probes metrics about every 180–300 seconds.
- Telemetry UCI section: `ha_watchdog_metrics.nodes`; summary options: `primary_summary` and `backup_summary`. Metrics are staged without committing every update to flash; values are volatile across reboot until fresh checks occur.
- HA: user has a UI-only configuration preference and does not edit `configuration.yaml` or server files manually. The installed HA was version 2026.2.3 and `ha-openwrt` 2.4.7 was the known working version. Existing VPN dashboard/helpers are preferred; do not create a separate dashboard unnecessarily.
- Latest confirmed mode is `auto`, route is `tLUhZHkw` (Netherlands), and the dynamic primary resolver found that ID after subscription refresh. The user reports YouTube now appears to load better on Netherlands than on Finland. Both nodes have returned HTTP 204; a natural return from backup to primary after the 600-second hold-down was observed. Do not treat this as a controlled outage test. Re-check live state before acting.

## Response / workflow preferences
- Respond in Russian unless asked otherwise; direct and practical.
- Work one step at a time, with short SSH commands, because long pasted blocks can be corrupted.
- Explain the effect and risk before any action that changes routing or service state.
- Use the repository to update durable notes after a meaningful verified change. Never store real secrets in it.
- When troubleshooting, first collect current state/logs, then suggest the smallest safe next step. Avoid pretending uncertain causes are established facts.

Your first response should briefly summarize the current architecture and list the most important unresolved risks/tests, citing the exact repository files you read. Do not change anything until asked.


## New protection caveat — 2026-10-23

The port-cache fix was verified with repeated successful HTTP 204 probes and a stable cache count of four. However, the live PassWall2 scripts currently remove the temporary port key on the normal cleanup path; an external timeout may terminate `test.sh` before that cleanup line executes. Do not claim timeout-path cleanup is fully solved yet. Before re-enabling `auto`, inspect/add safe signal cleanup, test both normal and timeout paths, and then implement a one-time confirmation probe for failed tests plus a recovery hold-down to reduce rapid route reversals. Current mode last confirmed by the user is `primary` with route `PusiSLgE`.


## Latest operational update — 2026-10-23

The status sections above may contain older notes saying protection work is pending. Those notes are historical; use this newer state:

- Live `/usr/share/passwall2/test.sh` has cleanup traps for the allocated temporary test port, associated test process, and temporary files. An intentionally interrupted probe returned timeout exit code 124 and left no matching temporary files; only unrelated `get_port_2001`–`get_port_2004` keys remained in the cache.
- Both live watchdog scripts now retry a failed node test once after 2 seconds. The failover core additionally has a 600-second backup-to-primary recovery hold-down, bypassed after three consecutive backup failures when the current primary probe succeeds.
- Syntax checks passed. Latest metrics-only probe returned HTTP 204 for both nodes (primary about 293 ms, backup about 377 ms, `ok=3 fail=0` each).
- Current live UCI mode is `auto`, route is `tLUhZHkw`; the primary resolver is installed and resolves the one imported node in group `stealthsurf`. Backup `fAk268mE` remains static. Runtime recovery from backup to primary after the hold-down was observed, but a controlled outage/recovery test is still pending. Inspect current logs before proposing more changes.


## Subscription-refresh resolver update — 2026-10-23

The live primary changed from `PusiSLgE` to `4m4hltgt` and then `tLUhZHkw` after switching the primary subscription from Finland to the Netherlands. The helper `/usr/bin/passwall2-failover-resolve-primary` resolves exactly one imported node where `add_mode=2` and `group=stealthsurf`; the core, wrapper and metrics-only probe call it instead of storing a fixed primary ID. The backup still uses fixed ID `fAk268mE`. The watchdog naturally returned from backup to the Netherlands node after cooldown at 20:50:59, and the user reports YouTube appears to load better. Controlled outage/recovery testing remains open.
