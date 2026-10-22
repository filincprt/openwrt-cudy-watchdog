# Backup inventory and rollback notes

These backups exist on the router, not in this repository. The `/tmp` state directory is volatile.

## Known router-side backup files

| Path | Meaning |
|---|---|
| `/usr/bin/passwall2-failover-core.bak-before-timeout` | Core before the probe was wrapped in `timeout -k 2 10` |
| `/usr/bin/passwall2-failover-before-status` | Earlier wrapper snapshot from status work |
| `/usr/bin/passwall2-failover-before-mode` | Earlier wrapper snapshot from mode work |
| `/usr/bin/passwall2-failover-before-webhook` | Earlier wrapper snapshot from webhook integration work |
| `/etc/crontabs/root.bak-before-watchdog-loop` | Crontab before removing the old minute-based watchdog cron line |
| `/etc/config/dropbear.bak-before-key-only` | Dropbear configuration copy from SSH-key work; inspect before restoring |
| `/root/.ssh/authorized_keys.bak` | Previous duplicate/un-normalized root authorized_keys file |

The live wrapper has a working Home Assistant webhook token; it is deliberately not backed up in this repository.

## General rollback rules

1. Confirm local access to LuCI/SSH before changing access controls.
2. Keep node IDs `PusiSLgE`, `fAk268mE`, `_direct` intact.
3. Restore only the file relevant to the incident. Do not overwrite `/etc/config/passwall2` or `/etc/config/network` as a generic repair.
4. Avoid running cron and the procd loop at the same time; they share the same core lock.

## Stop or disable only the service

```sh
/etc/init.d/passwall2-failover-watchdog stop
/etc/init.d/passwall2-failover-watchdog disable
```

This stops the supervisor; it does not restore a route or update HA state. Inspect selected node and status afterward.

## Restore previous cron schedule (only if intentionally reverting)

The saved snapshot is `/etc/crontabs/root.bak-before-watchdog-loop`. Inspect it before restoring. The snapshot predates removal of the watchdog cron line and may therefore cause duplicate scheduling if the procd service is still enabled. Do not restore it while the service is running.

## Restore core without timeout wrapper

```sh
cp -p /usr/bin/passwall2-failover-core.bak-before-timeout /usr/bin/passwall2-failover-core
sh -n /usr/bin/passwall2-failover-core
```

This removes the guard against a long-running probe and is not recommended without a specific reason.


## Telemetry gate backup — 2026-10-22

A router-side backup was created before connecting the publication gate:

- `/usr/bin/passwall2-failover-core.bak-before-metrics-throttle`

The telemetry publisher was also backed up during the UCI delta/revert fix:

- `/usr/bin/passwall2-watchdog-publish-metrics.bak-before-revert-fix`
- `/tmp/ha_watchdog_metrics.uci-delta.bak` (runtime UCI delta backup; the old 48.8 KB delta was then reverted)

The current publication-gate script is `/usr/bin/passwall2-watchdog-publish-due`. Its creation and connection to the core were syntax-checked, but the new auto-mode timing still needs runtime verification.

Before restoring the core backup, inspect the exact file and confirm its compatibility with the currently installed publisher. Restoring the core alone can remove the throttled publication call; it should not affect the route logic except to restore the earlier core version.
