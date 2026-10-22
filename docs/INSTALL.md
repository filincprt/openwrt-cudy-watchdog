# Deployment and adaptation guide

This guide explains how to adapt the watchdog to another OpenWrt + PassWall2 router. It deliberately avoids a blind one-command installer: PassWall2 node IDs and generated files are installation-specific, and the checked-in scripts are reference snapshots.

## 0. Before starting

You need:

- OpenWrt with shell access and a working LuCI/SSH recovery path.
- PassWall2 and Xray already installed and able to connect through each candidate node.
- A primary node and a backup node that can be tested separately.
- BusyBox `ash`, `uci`, `logger`, `timeout`, and the PassWall2 test script (the reference install uses `/usr/share/passwall2/test.sh`).
- Optional: Home Assistant with an OpenWrt integration that can read UCI values and execute allowed commands.

Do not proceed if you cannot identify the actual node IDs, the active-route UCI option, the Xray validation command, or a way to recover the router locally.

### Capture the baseline first

Run read-only commands and save the output outside the router:

```sh
ubus call system board
opkg list-installed 2>/dev/null | grep -Ei 'passwall|xray|curl|coreutils-timeout'
apk info 2>/dev/null | grep -Ei 'passwall|xray|curl|timeout'
uci -q get passwall2.rulenode.default_node
uci show passwall2 | grep -E 'nodes|remarks|default_node|url_test_url'
ls -l /usr/share/passwall2/test.sh
/etc/init.d/passwall2 status
```

Package manager commands vary by OpenWrt release. A failed `opkg` command on a release using `apk` is not itself an installation failure.

Inspect your own `/etc/config/passwall2` locally. Do not paste subscription URLs, credentials, UUIDs, private keys, or full node configuration into an issue or public chat. Record the stable way to identify primary and backup nodes; do not assume another router uses the example IDs.

## 1. Understand the pieces

| Piece | Responsibility |
|---|---|
| Core | Probes primary and backup; maintains consecutive counters; decides whether to switch routes |
| Wrapper | Reads the control mode, pins primary/backup/direct in manual modes, calls the core in auto, and reports state |
| Loop | Repeats the wrapper, adds a randomized pause, logs output |
| procd init service | Starts and respawns the loop at boot |
| Metrics-only probe | Used in manual modes; measures both nodes without changing the route |
| Metrics publisher | Converts probe results into UCI telemetry values |
| Publication gate | In auto mode, throttles telemetry writes without throttling the core's health probes |
| Home Assistant | Optional control surface, polling, dashboard and notifications |

The route-decision counters and metrics-only counters must remain separate. A metrics-only script must never edit `passwall2.rulenode.default_node`, restart PassWall2, or update the core's decision counters.

## 2. Adapt and install the OpenWrt scripts

### Important

The scripts in `scripts/` are sanitized reference snapshots. Before deploying, compare each one with the live script from the reference installation and confirm it matches the intended version. The repository now includes a sanitized reference for the telemetry publication gate. It is still a reference snapshot: compare it with the live router before deployment, and do not infer that a matching filename guarantees matching contents.

Recommended rollout order:

1. Make a separate backup of every file you will edit.
2. Adapt primary and backup IDs in both core and wrapper, or implement stable role resolution with missing/ambiguous-match safeguards.
3. Confirm the test command works for each node independently and returns an expected result such as `204:0.3...`.
4. Adapt the active route UCI path and Xray validation path to the target PassWall2 version.
5. Install the core, wrapper, loop, and init script only after inspecting them line by line.
6. Install telemetry scripts only after confirming the full contents and interfaces of all helpers.
7. Set executable permissions and syntax-check each shell script.
8. Start the service in a safe manual mode first, then inspect the route and logs.
9. Enable boot start only after the manual checks pass.

### Reference paths

```text
/usr/bin/passwall2-failover-core
/usr/bin/passwall2-failover
/usr/bin/passwall2-failover-loop
/usr/bin/passwall2-watchdog-publish-metrics
/usr/bin/passwall2-watchdog-publish-due
/usr/bin/passwall2-watchdog-probe-metrics
/etc/init.d/passwall2-failover-watchdog
/etc/config/ha_watchdog
/etc/config/ha_watchdog_metrics
```

The live files may differ from repository snapshots. Do not overwrite a file merely because the path matches.

### UCI model

The reference wrapper expects:

- `ha_watchdog.main.mode`: `auto`, `primary`, `backup`, or `off`.
- `ha_watchdog.main.status`: reported state such as `primary`, `backup`, `direct`, `offline`, `manual_off`, or `unknown`.
- `passwall2.rulenode.default_node`: selected node ID.
- `ha_watchdog_metrics.nodes`: volatile telemetry fields.

The exact `uci set` syntax to create a new config section depends on the desired schema. Inspect existing configs first and use `uci changes` to review staged changes. Do not commit the metrics config on every check: that would create unnecessary flash writes. Telemetry in this implementation is runtime/staged state and resets to defaults after reboot until a new check publishes values.

### Syntax and service checks

```sh
sh -n /usr/bin/passwall2-failover-core
sh -n /usr/bin/passwall2-failover
sh -n /usr/bin/passwall2-failover-loop
sh -n /usr/bin/passwall2-watchdog-publish-metrics
sh -n /usr/bin/passwall2-watchdog-publish-due
sh -n /usr/bin/passwall2-watchdog-probe-metrics
/etc/init.d/passwall2-failover-watchdog status
logread | grep 'passwall2-watchdog' | tail -n 40
uci -q get ha_watchdog.main.mode
uci -q get passwall2.rulenode.default_node
```

Skip a syntax check only if the corresponding script is not installed. Do not hide a failure by chaining a destructive action after a failed check.

### Enable/disable

Once the service script has been verified:

```sh
/etc/init.d/passwall2-failover-watchdog enable
/etc/init.d/passwall2-failover-watchdog start
/etc/init.d/passwall2-failover-watchdog status
```

To stop only the watchdog:

```sh
/etc/init.d/passwall2-failover-watchdog stop
```

To stop it from starting at boot:

```sh
/etc/init.d/passwall2-failover-watchdog disable
```

Check `/etc/crontabs/root` and remove or disable any old watchdog cron job before enabling the procd loop. Keep unrelated cron jobs such as subscription refresh intact. Do not restore a whole old crontab blindly.

## 3. Deployment without Home Assistant

Home Assistant is optional. The core's route decisions and procd loop can run on OpenWrt without an HA dashboard, provided the wrapper's UCI mode/status model is retained or the wrapper is deliberately adapted.

Before running without HA:

1. Inspect the wrapper for the webhook call.
2. Disable the callback safely (for example, make it conditional on a non-empty webhook URL); do not leave a real token in the script template or repository.
3. Ensure `ha_watchdog.main.mode` has an explicit value. Use `auto` only after verifying both node IDs and route logic.
4. If no HA UI is present, change the mode with UCI from a local SSH session only after understanding the consequences.

Example inspection/change sequence (adapt to the target router; do not paste unreviewed):

```sh
uci -q get ha_watchdog.main.mode
uci -q get passwall2.rulenode.default_node
uci show ha_watchdog
```

To choose automatic mode, the reference config uses:

```sh
uci set ha_watchdog.main.mode='auto'
uci commit ha_watchdog
/usr/bin/passwall2-failover
```

The final command invokes the wrapper once; it can change the route and restart PassWall2. Run it only when that behavior is intended and local recovery access is available.

Without HA, the UCI telemetry values can still be inspected over SSH, but there is no dashboard or HA notification surface. If telemetry is not needed, the metrics scripts can be omitted only after removing their calls from the core/loop and syntax-checking the result.

## 4. Deployment with Home Assistant

The router-side watchdog must work safely before adding HA. HA is a control/visualization layer, not a requirement for core failover.

The reference setup uses Home Assistant UI automations and the `ha-openwrt` integration. Integration versions and action schemas differ; verify actions in Developer Tools before copying YAML from another version.

### Helpers

Create/select helpers in the existing VPN dashboard area; do not create a second dashboard unless desired:

- `input_select.passwall2_mode` — Auto, Primary, Backup, VPN off.
- `input_select.passwall2_status` — human-readable status.
- `input_text.passwall2_primary_metrics` — primary summary.
- `input_text.passwall2_backup_metrics` — backup summary.

The reference telemetry values are available via UCI paths such as:

```text
ha_watchdog_metrics.nodes.primary_summary
ha_watchdog_metrics.nodes.backup_summary
ha_watchdog_metrics.nodes.primary_ok
ha_watchdog_metrics.nodes.backup_ok
ha_watchdog_metrics.nodes.primary_rtt_ms
ha_watchdog_metrics.nodes.backup_rtt_ms
ha_watchdog_metrics.nodes.primary_failures
ha_watchdog_metrics.nodes.backup_failures
ha_watchdog_metrics.nodes.last_check
```

### Automations

The reference design uses these responsibilities:

1. **Apply mode:** map the selected mode helper to `ha_watchdog.main.mode`, then call the router wrapper.
2. **Status update:** poll `ha_watchdog.main.status` and update the status helper.
3. **Webhook event:** accept router state-change notifications, then read UCI and synchronize the helper.
4. **Metrics poll:** read `primary_summary` and `backup_summary` and set the two text helpers. The reference polling interval is 30 seconds; the underlying metric values are only published every 3–5 minutes in the latest design, so frequent HA reads do not themselves create VPN-node probes.
5. **Voice notification (optional):** announce state changes through the configured media player.

Use the HA UI automation editor if configuration files cannot be edited. Test each action's actual response shape before using `response_variable` or templating it. Never invent response field names.

### Webhook secret handling

- Generate/use a high-entropy webhook ID.
- Keep the real URL only on the trusted router/HA configuration.
- Use a redacted placeholder in repository examples.
- Do not commit HA tokens, webhook IDs, or full URLs that include secrets.
- Test the endpoint only from a trusted network and avoid printing the full URL in logs.

## 5. Scheduling and expected load

The latest intended design is:

- **Auto mode:** two sequential health probes every full core cycle; randomized 5–15 second pause after the cycle. The actual interval includes probe execution time.
- **Telemetry in auto:** the publication gate allows UCI telemetry to refresh on a randomized 180–300 second schedule; this gate must not wrap or skip the core probes.
- **Manual primary/backup/off:** wrapper pins the selected route and exits early; loop performs a separate metrics-only probe of both nodes and then waits a randomized 180–300 seconds.
- **Probe timeout:** 15 seconds plus a 2-second kill grace in the live reference core and metrics-only checker.
- **Decision threshold:** three consecutive failures for failover decisions using the failure counters; primary recovery uses three consecutive successful checks.

Lower probe frequency reduces requests but delays outage detection. A random delay is not an anonymity or anti-blocking guarantee. Confirm the actual interval in logs after changing scheduling.

## 6. Verification and safe testing

Start with normal connectivity:

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node PRIMARY_NODE_ID urltest_node
echo "EXIT_CODE=$?"
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node BACKUP_NODE_ID urltest_node
echo "EXIT_CODE=$?"
```

Replace the placeholders with the actual IDs. A response like `204:0.35` and exit code 0 is the expected healthy example in the reference installation.

Then verify:

- service is running;
- mode and selected route are as intended;
- both nodes return expected probe results;
- counters reset on successful checks and rise on failures;
- route changes are logged and Xray validation succeeds;
- telemetry publication is throttled while health probes continue;
- reboot restores the service and expected persistent mode.

Do not force both nodes offline when remote SSH/LuCI depends on them. A controlled failure/recovery test should be done only with local access or an independent recovery path.

## 7. Rollback

1. Stop the watchdog service.
2. Restore only the specific backed-up script you changed.
3. Run `sh -n` on restored scripts.
4. Inspect `uci show passwall2` and `uci show ha_watchdog`.
5. Start/re-enable the service only after verifying route and mode.

See [Backups and rollback](BACKUPS.md) and [Diagnostics](DIAGNOSTICS.md).


## 7. Repository handoff / continuing with another AI

Use [AI-PROMPT.md](AI-PROMPT.md) to transfer the project's durable context to another model. Always instruct the model to read the latest `STATUS.md` and `CHANGELOG.md` before making assumptions. Keep secrets and raw router backups out of the repository.
