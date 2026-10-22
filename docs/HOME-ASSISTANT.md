# Home Assistant integration

Sanitized reference as of 2026-10-22. No working webhook token is included.

## Home Assistant host / integration

- Local HA URL: `http://192.168.50.187:8123/`.
- Home Assistant version observed: `2026.2.3`; user asked not to update it during prior work.
- OpenWrt integration: `ha-openwrt` version 2.4.7. Version 2.5.3 previously had compatibility trouble.
- HA entry ID: `01M5EXZ6JCC1KKMS3X1V2DANYD`.
- OpenWrt integration actions `openwrt.uci_get` and `openwrt.execute_command` were tested successfully.

## Watchdog state

UCI configuration on router:
- `ha_watchdog.main.mode`: `auto`, `primary`, `backup`, or `off`.
- `ha_watchdog.main.status`: `primary`, `backup`, `manual_off`, `direct`, `offline`, or `unknown`.
- Latest observed `ha_watchdog.main.mode` is `auto`, selected route `PusiSLgE` (confirmed 2026-10-22 after enabling automatic failover).
- Wrapper webhook URL path is `/api/webhook/<REDACTED>`; do not copy the real token into this repository.

## Helper entities

Status helper: `input_select.passwall2_status`, with options:
- `Основной узел`
- `Резервный узел`
- `VPN отключён вручную`
- `Прямое подключение`
- `Оба узла недоступны`
- `Неизвестно`

Mode helper: `input_select.passwall2_mode`, with options:
- `Авто`
- `Основной узел`
- `Резервный узел`
- `VPN выключен`

Automations discussed:
- `PassWall2 — событие от роутера`: receives the router webhook, reads UCI status, maps it to the status helper.
- `PassWall2 — применение режима`: maps the selected helper mode to UCI and calls the wrapper.
- `PassWall2 — обновление статуса`: polls status periodically.
- `PassWall2 — голосовые уведомления`: reports status changes through Yandex Station.

## Yandex Station

- Entity: `media_player.yandex_station_ff98f02944cd4b0dd5775c8b`.
- `media_player.play_media` with `media_content_type: text` and `media_content_id: ...` was tested successfully for TTS in a direct `data:` payload. Do not reintroduce a nested `media:` wrapper without retesting.

## Webhook test

From OpenWrt, POST to the configured HA webhook returned HTTP 200. The actual webhook token has intentionally been omitted. To test on the live router, inspect the exact local wrapper and call the configured webhook only from a trusted network. Never put the token in issue comments, chat logs, public repositories or sanitized backups.


## PassWall2 node metrics — router side ready, HA display pending (2026-10-22)

OpenWrt publishes volatile UCI fields under `ha_watchdog_metrics.nodes`:

| Option | Meaning |
|---|---|
| `primary_ok`, `backup_ok` | `online` / `offline` from the most recent probe |
| `primary_result`, `backup_result` | Raw HTTP result (e.g. `204:0.353328`) or `no-response` |
| `primary_rtt_ms`, `backup_rtt_ms` | Rounded latency in milliseconds, or `unknown` |
| `primary_failures`, `backup_failures` | Consecutive failed probe count, capped at 3 |
| `primary_checked_at`, `backup_checked_at`, `last_check` | Local router timestamp |

Router-side telemetry was verified by reading `uci show ha_watchdog_metrics`; both probes returned HTTP 204 and counters were 0. Watchdog logs confirmed that telemetry refresh runs in manual mode after the service restart. The existing VPN dashboard now shows two summaries through `input_text.passwall2_primary_metrics` and `input_text.passwall2_backup_metrics`. A UI-created polling automation reads the `primary_summary` and `backup_summary` UCI options through `openwrt.uci_get` every 30 seconds. The displayed summary timestamp is the time of the router probe, not the time the card was refreshed.


## Confirmed telemetry display and publication throttle — 2026-10-22

The two metric summaries were displayed in the existing VPN section:

- Primary: online, HTTP 204, RTT 300 ms, failures 0.
- Backup: online, HTTP 204, RTT 367 ms, failures 0.
- Both checks were stamped `2026-10-22 22:37:42`.

The router-side publisher uses UCI staged values, not a flash commit on each update. The `passwall2-watchdog-publish-due` helper now limits publication in automatic mode to a randomized 180–300 second interval. HA's 30-second polling does not itself create a VPN probe; it reads the already-published summary. Manual mode also performs metrics-only checks every randomized 180–300 seconds. Automatic mode still probes both nodes each core cycle.
