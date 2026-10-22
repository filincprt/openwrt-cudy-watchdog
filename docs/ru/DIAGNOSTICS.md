# Сборник команд диагностики

Команды в этом документе предназначены для чтения состояния, если явно не указано иное.

## Служба и расписание

```sh
/etc/init.d/passwall2-failover-watchdog status
ls -l /etc/rc.d/*passwall2-failover-watchdog
cat /etc/crontabs/root
ps w | grep -E '[p]asswall2-failover-loop|[p]asswall2-failover-core'
```

## Режим, состояние и счётчики

```sh
uci -q get ha_watchdog.main.mode
uci -q get ha_watchdog.main.status
uci -q get passwall2.rulenode.default_node
for f in /tmp/passwall2-failover-state/*; do echo "--- $f"; cat "$f"; done
ls -ld /tmp/passwall2-failover.lock 2>&1
```

## Логи

```sh
logread | grep 'passwall2-watchdog' | tail -n 40
logread | grep -Ei 'passwall2-failover|failover' | tail -n 80
```

## Ручная проверка обоих узлов

Перед запуском убедитесь, что ID всё ещё правильные:

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node PusiSLgE urltest_node
echo "EXIT_CODE=$?"
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node fAk268mE urltest_node
echo "EXIT_CODE=$?"
ps w | grep -E '[u]rl_test_PusiSLgE|[u]rl_test_fAk268mE'
```

Ожидаемый результат при исправном узле — HTTP `204` и код завершения `0`. Успешный ручной тест доказывает только результат именно этой попытки, а не то, что плановая проверка всегда успешна.

## Firewall и интерфейсы

```sh
/etc/init.d/firewall status
fw4 print >/dev/null && echo 'fw4: OK'
uci show firewall
ubus call network.interface.wan status
ubus call network.interface.wan6 status
ip route show default
ip -6 route show default
```

## Синтаксис shell

В используемой сборке OpenWrt утилиты `nl` не было. Для просмотра строк используйте, например, `sed -n '1,150p' FILE` или найдите нужные места командой `grep -n`.

## Проверка ограничителя телеметрии

В автоматическом режиме проверки узлов выполняются на каждом цикле, но публикация метрик через `passwall2-watchdog-publish-due` ограничена случайным интервалом 180–300 секунд.

```sh
cat /tmp/passwall2-failover-state/metrics_last_publish 2>/dev/null
cat /tmp/passwall2-failover-state/metrics_interval 2>/dev/null
uci -q get ha_watchdog_metrics.nodes.last_check
uci -q get ha_watchdog_metrics.nodes.primary_summary
uci -q get ha_watchdog_metrics.nodes.backup_summary
logread -e passwall2-watchdog | tail -n 30
```

## Режим и расписание метрик одним набором

```sh
echo "MODE=$(uci -q get ha_watchdog.main.mode)"
echo "ROUTE=$(uci -q get passwall2.rulenode.default_node)"
/etc/init.d/passwall2-failover-watchdog status
echo "LAST_PUBLISH=$(cat /tmp/passwall2-failover-state/metrics_last_publish 2>/dev/null)"
echo "PUBLISH_INTERVAL=$(cat /tmp/passwall2-failover-state/metrics_interval 2>/dev/null)"
echo "LAST_METRICS=$(uci -q get ha_watchdog_metrics.nodes.last_check)"
logread -e passwall2-watchdog | tail -n 40
logread -e passwall2-watchdog-metrics | tail -n 20
```

Сравните обычные строки проверок ядра и изменения `last_check` хотя бы на протяжении двух циклов. Проверки должны продолжаться на обычной частоте, а значения UCI — обновляться только при открытии окна публикации. В ручных режимах сама проверка метрик проходит раз в 180–300 секунд.

Файлы состояния в `/tmp/passwall2-failover-state` исчезают после перезагрузки. Отсутствующая временная метка сразу после старта может означать, что первая публикация ещё не состоялась.

Живые скрипты и проверка метрик используют `timeout -k 2 15`. Не публикуйте вывод конфигурации, содержащий подписки, ключи или другие данные доступа.

