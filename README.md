# OpenWrt PassWall2 Failover Watchdog

A small, shell-based failover watchdog for OpenWrt + PassWall2. It can run on its own or report state and telemetry to Home Assistant (HA). This repository is both a reusable reference implementation and an operational notebook: **read the safety notes and inspect the scripts before deploying them**.

> **Status: reference project, not a universal one-click installer.** The live setup was developed on a Cudy WR3000S AX3000 V2 with OpenWrt 25.12.6 and PassWall2. A clean install on another router/PassWall2 build has not been certified. The included IDs, paths, UCI options and Xray validation path must be adapted and tested.

## What it does

- Probes configured primary and backup PassWall2 nodes using PassWall2's `test.sh url_test_node` test.
- Tracks consecutive success/failure counters; the configured live policy uses a threshold of **3 consecutive failures** and **3 consecutive successes** for recovery decisions.
- In automatic mode, can route to the primary, backup or `_direct` fallback based on the observed node state.
- Runs under OpenWrt `procd` and starts on boot.
- Adds random delay to reduce rigid timing: the live loop uses a random 5–15 second pause after each automatic probe cycle.
- Publishes optional telemetry for Home Assistant: online/offline state, HTTP result, approximate RTT, consecutive failures and local timestamp.
- In manual modes, probes for telemetry without changing the selected route.
- Uses UCI staged changes for frequent telemetry rather than committing metrics to flash on every update.
- Includes diagnostic commands, backup/rollback notes, HA UI automation guidance and an AI handoff prompt.

### Modes

| `ha_watchdog.main.mode` | Meaning |
|---|---|
| `auto` | Run health probes and allow automatic route decisions. |
| `primary` | Pin the configured primary node; no automatic failover. |
| `backup` | Pin the configured backup node; no automatic failover. |
| `off` | Pin direct routing (`_direct`); no automatic VPN failover. |

Do not confuse the watchdog's `auto` control mode with a native PassWall2 URLTest group. In this implementation, the core changes `passwall2.rulenode.default_node` among configured node IDs and `_direct`.

## Architecture

```text
procd service
  └─ passwall2-failover-loop
       ├─ passwall2-failover (mode wrapper)
       │    ├─ manual mode: pin selected route and return
       │    └─ auto mode: passwall2-failover-core
       │         ├─ probe primary and backup
       │         ├─ update decision counters
       │         ├─ publish-due (telemetry throttle)
       │         └─ change route only when decision rules say so
       └─ manual modes only: metrics-only probe, no route changes
```

Current live schedule (2026-10-22):
- **Auto mode:** each full core cycle probes both nodes; the loop adds a random 5–15 second pause. Total cycle time also includes both probe runtimes, so it is not simply 5–15 seconds.
- **Metrics publication:** in auto mode, the core invokes `passwall2-watchdog-publish-due`; that helper allows UCI telemetry publication about every random 180–300 seconds. Health probes and failover decisions continue on every core cycle.
- **Manual primary/backup/off:** loop runs the metrics-only probe and waits a random 180–300 seconds before the next cycle.
- Timeouts are currently set to `timeout -k 2 15` in the live core and metrics-only probe.
- Jitter and a low-frequency telemetry publication reduce repetitive writes/requests, but **do not guarantee that a server will not be blocked**.

## Repository map

- [Quick deployment overview](docs/DEPLOYMENT.md) — deployment stages and safety gates.
- [Detailed install/adaptation guide](docs/INSTALL.md) — step-by-step setup with and without Home Assistant.
- [Watchdog internals](docs/WATCHDOG.md) — decision logic, intervals, limitations.
- [Home Assistant](docs/HOME-ASSISTANT.md) — helpers, UI automations, metrics and webhook safety.
- [Current status](docs/STATUS.md) — last verified live state and unresolved tests.
- [Diagnostics](docs/DIAGNOSTICS.md) — read-only checks and manual probe commands.
- [Backups / rollback](docs/BACKUPS.md) — recovery-first operating notes.
- [Firewall / SSH](docs/FIREWALL.md) — prior audit and cautions.
- [Change log](CHANGELOG.md) — notable live changes.
- [AI prompt](docs/AI-PROMPT.md) — reusable prompt to make another model treat this repository as the source of truth.
- `scripts/` — **sanitized reference snapshots**, not necessarily identical to the latest live files and not drop-in safe until compared.

## Quick health check

Run these on the router:

```sh
/etc/init.d/passwall2-failover-watchdog status
uci -q get ha_watchdog.main.mode
uci -q get ha_watchdog.main.status
uci -q get passwall2.rulenode.default_node
logread -e passwall2-watchdog | tail -n 30
uci -q get ha_watchdog_metrics.nodes.primary_summary
uci -q get ha_watchdog_metrics.nodes.backup_summary
```

Healthy probe results commonly look like `204:0.35...`; the exact HTTP code and latency vary. `no-response` means the probe did not return a recognized 2xx/3xx result. Check logs and run isolated probes before deciding that a VPN node is dead.

## Safety / privacy

1. **Keep this repository private** unless you have thoroughly scrubbed all environment-specific details.
2. Never commit live `/etc/config/passwall2`, subscription URLs, node credentials, passwords, private SSH keys, Home Assistant long-lived tokens, or a working webhook URL/token.
3. Replace example node IDs and LAN addresses with your own values. Node IDs may change after subscription refresh.
4. Back up configs and scripts before editing. Keep local LuCI/SSH access available during tests.
5. Do not test a failover by disabling both nodes when remote access is the only way back in.
6. A running procd service is not proof that automatic probes are active: in manual modes, the wrapper pins the chosen route and exits before the core.
7. A controlled, repeatable outage/recovery test is still required before relying on this for unattended recovery.
8. Telemetry is observational. It must not be mistaken for a route-selection command.
9. The scripts rely on PassWall2 internal paths and output formats that can change between versions.
10. This project does not promise evasion of network filtering or immunity from provider/server blocking.

## Current lab snapshot

Last known target device: Cudy WR3000S AX3000 V2; OpenWrt 25.12.6 `r33311-981c978eff`; PassWall2 with Xray; LAN `192.168.50.1`. The live primary/backup IDs are intentionally recorded in private operational notes, but examples for other users should be treated as placeholders. The latest conversational confirmation was `ha_watchdog.main.mode=auto`, route `PusiSLgE`; automatic failure/recovery has not yet passed a controlled end-to-end test. See [STATUS](docs/STATUS.md) for dated observations and uncertainty.
