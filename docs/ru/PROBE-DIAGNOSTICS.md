# Диагностика URL-test PassWall2 после reboot

Дата наблюдения: 2026-10-24. **Команды диагностики ниже пока не выполнялись на роутере**, это безопасный следующий план.

## Симптом и факты

- После полной перезагрузки роутера пользователь сообщил, что заблокированные сервисы не работали через основной/Auto-маршрут; после ручного выбора «Резервный» доступ восстановился.
- После возврата в Auto watchdog записал `Route changed: fAk268mE -> AnMllbuc` (17:35:36 по часам роутера), затем долго сообщал `Current: AnMllbuc; target: AnMllbuc`.
- Секция `ha_watchdog_metrics.nodes` на 2026-10-24 17:42:53: primary `204:0.345848`, RTT 346 ms, failures 0; backup `204:0.315927`, RTT 316 ms, failures 0.
- Активный `/usr/share/passwall2/test.sh` из предоставленного пользователем кода читает `config_n_get @global_other[0] url_test_url https://www.google.com/generate_204` и выполняет `curl -I -o /dev/null -skL ... -x socks5h://127.0.0.1:<port>` через временный SOCKS, поднятый для указанного node ID.
- `uci -q get 'passwall2.@global_other[0].url_test_url'` вернул пустое значение; значит, используется fallback Google `generate_204`.
- HTTP 204 проверяет только заданный endpoint. Он не доказывает, что YouTube видео/медиа (`googlevideo.com`) или другие отдельно заблокированные сервисы работают. Это правдоподобная причина расхождения, но не доказанная единственная причина.

## Проверенные источники PassWall2

В официальном LuCI-файле PassWall2 у параметра «URL Test Address» есть варианты Cloudflare, Gstatic, Google и YouTube, включая `https://www.youtube.com/generate_204`:
- [PassWall2 node_list.lua](https://github.com/Openwrt-Passwall/openwrt-passwall2/blob/main/luci-app-passwall2/luasrc/model/cbi/passwall2/client/node_list.lua)
- [PassWall2 test.sh (upstream PassWall version, same test pattern)](https://github.com/Openwrt-Passwall/openwrt-passwall/blob/main/luci-app-passwall/root/usr/share/passwall/test.sh)

Не менять глобальную опцию, пока не проверены узлы по отдельности. Позже, если отдельный тест подтвердит, что Google работает через primary, но YouTube endpoint доступен только через backup, можно обсудить выбор YouTube в UI PassWall2 «Node List → Other Settings → URL Test Address». Поскольку watchdog тоже читает этот UCI-параметр, смена затронет решения watchdog; сначала явно согласовать последствия. Даже YouTube generate_204 не гарантирует работоспособность всего видеопотока.

## Изолированная проверка YouTube через оба узла (не влияет на default_node)

Цель: запустить копию test.sh в `/tmp`, изменив **только в копии** fallback URL и имена временных SOCKS/config-файлов. Не менять UCI и не менять PassWall2 Auto.

### 1. Подготовить временную копию

Проверить, что текущий UCI URL всё ещё пустой, затем выполнить:

```sh
sed -e 's#https://www.google.com/generate_204#https://www.youtube.com/generate_204#g' \
    -e 's#url_test_\${#url_test_yt_\${#g' \
    /usr/share/passwall2/test.sh > /tmp/passwall2-test-youtube.sh
chmod 700 /tmp/passwall2-test-youtube.sh
sh -n /tmp/passwall2-test-youtube.sh
grep -n -E 'probeUrl=|flag=|config_file=|_pid_file=' /tmp/passwall2-test-youtube.sh
```

Вторая замена добавляет отдельный уникальный префикс к временным именам, чтобы не конфликтовать с штатным watchdog. До запуска проверить глазами, что:
- `probeUrl` по умолчанию указывает на `https://www.youtube.com/generate_204`;
- временный `flag`, `config_file`, pid path и cleanup используют префикс `url_test_yt_`;
- `sh -n` завершился без ошибок.

### 2. Проверить primary и backup раздельно

Выполнять последовательно, по одной команде. Это запускает отдельный короткий SOCKS-probe для каждого указанного узла, **не изменяя** `passwall2.rulenode.default_node` или `ha_watchdog.main.mode`:

```sh
/usr/bin/timeout -k 2 15 /tmp/passwall2-test-youtube.sh url_test_node AnMllbuc urltest_node
```

```sh
/usr/bin/timeout -k 2 15 /tmp/passwall2-test-youtube.sh url_test_node fAk268mE urltest_node
```

Ожидаемый результат в формате HTTP-код:время, например `204:0.4...`; `200` также успешен для URL-test. `000`, тайм-аут или 4xx/5xx означают, что этот endpoint через этот узел не прошёл ожидаемую проверку. Один endpoint остаётся только индикатором достижимости, а не гарантией воспроизведения видео.

### 3. Уборка

После обоих тестов удалить только созданную временную копию:
```sh
rm -f /tmp/passwall2-test-youtube.sh
```

Не удалять `/tmp/etc/passwall2/url_test_*` вручную без проверки; штатная cleanup-функция копии должна убирать её собственные временные файлы и процесс.

## Возможные результаты

- Primary Google=204 и YouTube=ошибка, backup YouTube=204: это сильное свидетельство, что Google-probe слишком узок для желаемого Auto; обсудить перевод глобального URL-test на YouTube через UI PassWall2, после чего проверить несколько циклов. Не изменять это без осознанного решения, так как это влияет и на watchdog.
- Оба узла YouTube=204, но видео всё ещё не воспроизводится через primary: проверить тест конкретного watch/video endpoint и DNS/QUIC/hostlist/фактический трафик; не делать вывод о полном доступе по generate_204.
- Primary YouTube=204, backup YouTube=204 и оба видео работают позже: возможно, был кратковременный стартовый race после boot; понадобятся логи времени старта сервисов/первой проверки и наблюдение, не слепой перенос задержек.
- Primary YouTube=ошибка, backup YouTube=ошибка: проверить сам endpoint/DNS/hostlist отдельно; не переключать настройки на основании одной пробы.

## Запрещённые до анализа действия

Не менять маршрут вручную, режим Auto, URL-test URL в постоянной конфигурации, ядро watchdog, стратегии zapret2 и Xray-exclude hook. Сначала выполнить read-only подтверждение и два изолированных probe-теста.
