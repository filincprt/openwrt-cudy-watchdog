# Home Assistant integration

Sanitized reference updated 2026-10-23. No working webhook token is included.

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
- Latest confirmed state after the user re-enabled Auto: `ha_watchdog.main.mode=auto`; logs at 2026-10-23 23:35–23:41 showed both nodes HTTP 204, `fail=0`, current/target `AnMllbuc`. Older `mode=primary` lines predate this change. A controlled real outage/recovery test remains pending.
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

The router-side publisher uses UCI staged values, not a flash commit on each update. The `passwall2-watchdog-publish-due` helper is intended to limit publication in automatic mode to a randomized 180–300 second interval. HA's 30-second polling does not itself create a VPN probe; it reads the already-published summary. Manual mode performs metrics-only checks every randomized 180–300 seconds. Automatic mode still probes both nodes each core cycle.

## Latest post-fix metrics — 2026-10-23 16:10

After fixing temporary test-port cache exhaustion in PassWall2's local test scripts, repeated primary/backup probes returned HTTP 204. The latest confirmed summaries showed primary online / RTT 313 ms / failures 0 and backup online / RTT 337 ms / failures 0. Keep the watchdog mode `primary` until longer stability and controlled failover/recovery are tested.


## Event push and Station quiet hours — 2026-10-24

- Helpers holding the newest event are `input_text.passwall2_last_event` and `input_text.passwall2_last_event_id`.
- The webhook automation reads `ha_watchdog.main.status`, `event_message`, and `event_id`; maps status to `input_select.passwall2_status`; updates the event helper; compares the incoming event ID with the stored ID to suppress duplicate pushes; and sends push to the Samsung A50 (`notify.mobile_app_sm_a505fn`) and PC (`notify.mobile_app_komputer`). The TECNO and second Samsung services are intentionally not targeted.
- A synthetic node-state test called `passwall2-watchdog-node-state primary offline ...` then `online`; the user confirmed two push notifications arrived. This proves handler/webhook/HA/push delivery, **not** an actual probe failure or automatic route change.
- The live event script extracts the webhook URL from the local `/usr/bin/passwall2-failover` wrapper at runtime. No active webhook token is committed to the repository.
- Quiet-hours helpers in the live HA instance: `input_boolean.passwall2_station_announcements`, `input_datetime.asswall2_station_start_time` (the actual entity ID contains the typo `asswall2`), and `input_datetime.passwall2_station_end_time`. The user set 08:00–23:00 and enabled the toggle. A conditional `media_player.play_media` action with `media_content_type: text` was added to the router-webhook automation, targeting the Yandex Station entity above. TTS has not yet been tested during the allowed window.
- **Important unresolved check:** the pre-existing `PassWall2 — голосовые уведомления` automation was not inspected/updated in this session. If it still speaks independently, it can bypass this quiet-hours guard. Before relying on overnight silence, ensure that automation is disabled or has the same toggle/time conditions.

