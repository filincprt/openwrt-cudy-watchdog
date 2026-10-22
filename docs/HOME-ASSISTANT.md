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
