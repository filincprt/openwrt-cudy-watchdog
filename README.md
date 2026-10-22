# OpenWrt PassWall2 Failover Watchdog

[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.12%2B-00A3E0)](https://openwrt.org/)
[![PassWall2](https://img.shields.io/badge/Proxy-PassWall2-6B5CE7)](#)
[![Home%20Assistant](https://img.shields.io/badge/Optional-Home%20Assistant-18BCF2)](docs/HOME-ASSISTANT.md)

A practical, documented reference for building a **two-node PassWall2 health-check and failover watchdog** on OpenWrt, with optional Home Assistant controls, telemetry, notifications, and a dashboard.

This repository is both a reusable example and an operations notebook. It records what was actually observed on one Cudy WR3000S V2 installation, separates verified behavior from assumptions, and keeps sanitized reference scripts. It is **not** a universal one-click installer.

> **Safety first:** do not paste these scripts onto a router blindly. Node IDs, PassWall2 paths, UCI schema, test-script behavior, package versions, and firewall topology differ between installations. Read [deployment and adaptation](docs/INSTALL.md), then inspect your own router. Never commit working credentials or webhook tokens.

## What it can do

- Probe a configured primary and backup PassWall2 node independently.
- Track consecutive successes and failures, with counters capped at three.
- In automatic mode, switch primary → backup when the primary has failed three consecutive checks and the backup is healthy.
- Use direct routing if both configured nodes have reached the failure threshold.
- Recover from direct or backup to the preferred primary after three successful primary checks, according to the documented state machine.
- Validate the generated Xray ACL configuration after a route change and attempt to restore the previous route if validation fails.
- Run as an OpenWrt `procd` service and start automatically after reboot.
- Add randomized delays rather than a perfectly fixed loop interval.
- Offer manual modes: pin primary, pin backup, force direct/off, or let the watchdog manage the route.
- Publish online/offline state, HTTP result, approximate RTT, consecutive failures, and timestamps through volatile UCI telemetry.
- Optionally expose status and mode controls in Home Assistant, refresh a dashboard, send notifications, and use a webhook to synchronize state.

The design intentionally keeps **route decisions** separate from **telemetry-only probes** in manual modes. Metrics must never change the selected route.

## Current reference installation

Last verified from the working session: **2026-10-22**.

| Component | Observed setup |
|---|---|
| Router | Cudy WR3000S AX3000 V2 |
| Firmware | OpenWrt 25.12.6, revision `r33311-981c978eff` |
| Proxy manager | PassWall2 + Xray |
| Primary / backup IDs | Stored as examples in the private reference install; IDs are hard-coded in the current script snapshots |
| Service | `/etc/init.d/passwall2-failover-watchdog`, managed by `procd` |
| Control mode | `auto` confirmed after the most recent mode change |
| Selected route | Primary node ID `PusiSLgE` at the last check |
| Probe timeout | `timeout -k 2 15` in the live core and metrics-only probe |
| Auto loop pause | Random 5–15 seconds **after** a full cycle |
| Manual-mode metrics pause | Random 180–300 seconds between loop iterations |
| Auto-mode metric publication | A new 180–300 second publication gate was added and passed shell syntax checks; its runtime cadence still needs verification |
| Home Assistant | Optional; the reference setup uses HA 2026.2.3 and `ha-openwrt` 2.4.7 |
| Persistent metrics writes | Avoided; telemetry values are staged in UCI runtime state and reset after reboot |

The pause is not the full cycle time. Each automatic cycle sequentially probes two nodes, so total elapsed time is probe execution time plus the randomized pause. If probes time out, the cycle may take substantially longer.

### Known limitations — read before use

- **Hard-coded node IDs:** the current reference core and wrapper use fixed primary and backup IDs. PassWall2 subscription refreshes or manual node edits may change those IDs or make the watchdog override an unfamiliar route. Resolve roles dynamically before treating this as subscription-safe.
- **Auto is the watchdog's mode, not a native PassWall2 URLTest group.** In `ha_watchdog.main.mode=auto`, this script makes its own route decisions by writing `passwall2.rulenode.default_node`.
- **False negatives and transient failures:** the probe tests a specific HTTP endpoint through each configured node. A successful `204` is evidence that this probe worked, not proof that every website works. A failed probe does not prove that the server was blocked.
- **No block-avoidance guarantee:** randomized timing and slower telemetry publication reduce regularity/request volume, but cannot guarantee that a provider or network operator will not identify or block a server.
- **Failure/recovery testing:** a controlled test of every failover branch remains pending. A reboot recovery was observed, but that is not the same as a controlled outage test.
- **Latest telemetry change:** `passwall2-watchdog-publish-due` was connected to the core and passed `sh -n`; the new publication interval should be verified in live logs before relying on it.

## Quick navigation

- **[Installation and adaptation guide](docs/INSTALL.md)** — with and without Home Assistant, checks, safe rollout, rollback.
- [Watchdog logic and scheduling](docs/WATCHDOG.md)
- [Current status / verified observations](docs/STATUS.md)
- [Home Assistant setup](docs/HOME-ASSISTANT.md)
- [Diagnostics cookbook](docs/DIAGNOSTICS.md)
- [Backups and rollback](docs/BACKUPS.md)
- [Firewall and SSH audit notes](docs/FIREWALL.md)
- [AI handoff prompt](docs/AI-PROMPT.md) — prompt an assistant to use this repository as the source of truth.
- [Change log](CHANGELOG.md)
- [Sanitized script snapshots](scripts/)

## Repository map

```text
README.md                         Project overview and safety rules
CHANGELOG.md                      Chronological implementation history
docs/INSTALL.md                   Adaptation/deployment guide
docs/STATUS.md                    Dated current-state snapshot
docs/WATCHDOG.md                  State machine, scheduling, limitations
docs/HOME-ASSISTANT.md            HA helpers, automations, telemetry
docs/DIAGNOSTICS.md               Read-only checks and troubleshooting
docs/BACKUPS.md                   Known backups and rollback
docs/FIREWALL.md                  Observational network/SSH notes
docs/AI-PROMPT.md                 Reusable AI context prompt
scripts/passwall2-failover-core.sh
scripts/passwall2-failover-loop.sh
scripts/passwall2-failover-watchdog.init
scripts/passwall2-failover.sh.example
```

Files under `scripts/` are **reference snapshots**, not guaranteed copies of the current router. They may lag behind live changes and must be compared before use. The sanitized wrapper contains a placeholder webhook token by design.

## Safety and privacy

1. Keep this repository private if it contains installation-specific context.
2. Never commit `/etc/config/passwall2`, subscription URLs, proxy credentials, private SSH keys, HA long-lived access tokens, or a real webhook URL/token.
3. Replace example IPs, node IDs, usernames, and entity IDs when adapting the guide. Do not assume the sample IDs are stable.
4. Back up each live file before editing it. Run `sh -n` after changes, then inspect logs and service state.
5. Do not test failover remotely if loss of both nodes would also remove your only access to LuCI/SSH.
6. Do not run the old cron watchdog and the `procd` loop concurrently; they can compete for the same lock.
7. Do not use a generic rollback that overwrites `/etc/config/passwall2`, `network`, or `firewall`.
8. Treat all commands in this repo as examples until paths, UCI options, service names, and node IDs are verified on the target router.

## Source-of-truth policy

For future maintenance, read this file plus [STATUS](docs/STATUS.md), [WATCHDOG](docs/WATCHDOG.md), [HOME-ASSISTANT](docs/HOME-ASSISTANT.md), and [CHANGELOG](CHANGELOG.md) before proposing changes. When live state and documentation disagree, ask for fresh read-only command output, update the dated status, and never silently assume either source is current.
