# Установка и адаптация: OpenWrt + PassWall2, с Home Assistant или без него

Это инструкция для аккуратного ручного развёртывания, а не установщик в один клик. Команды разделены на небольшие этапы, чтобы можно было проверять результат. ID узлов, пути, тайм-ауты, тестовый URL и команда проверки Xray должны соответствовать именно вашей системе.

## 0. Требования и область применения

Нужно:
- OpenWrt с рабочим доступом по SSH/LuCI и установленным PassWall2;
- два работающих прокси-узла PassWall2 — основной и резервный — и поддерживаемая локальной конфигурацией цель прямого подключения `_direct`;
- файл `/usr/share/passwall2/test.sh` с действием `url_test_node`;
- `/usr/bin/timeout`, `curl`, `uci`, `logger`, `awk` и BusyBox `ash`;
- необязательно: доступный Home Assistant и совместимая интеграция OpenWrt.

**Не используйте приведённые ниже ID, если они не совпадают с ID на вашем роутере.** В исходной лабораторной конфигурации `PusiSLgE` был основным, а `fAk268mE` — резервным. Это примеры из конкретной установки. Обновление подписки может изменить внутренние ID.

## 1. Сначала сделайте резервную копию

Выполните по SSH на роутере и скопируйте резервные файлы в безопасное место вне роутера:

```sh
mkdir -p /root/watchdog-backup
cp -p /etc/config/passwall2 /root/watchdog-backup/passwall2
cp -p /etc/config/firewall /root/watchdog-backup/firewall
cp -p /etc/config/network /root/watchdog-backup/network
cp -p /etc/config/dropbear /root/watchdog-backup/dropbear
cp -p /usr/bin/passwall2-failover /root/watchdog-backup/passwall2-failover 2>/dev/null
cp -p /usr/bin/passwall2-failover-core /root/watchdog-backup/passwall2-failover-core 2>/dev/null
cp -p /usr/bin/passwall2-failover-loop /root/watchdog-backup/passwall2-failover-loop 2>/dev/null
cp -p /etc/init.d/passwall2-failover-watchdog /root/watchdog-backup/passwall2-failover-watchdog 2>/dev/null
```

Храните каталог в приватном месте: конфигурация PassWall2 может содержать секреты. Не загружайте её в репозиторий.

## 2. Найдите локальные ID узлов и проверьте тест

Не вставляйте URL подписок и реквизиты узлов в чат или GitHub.

```sh
uci show passwall2 | grep -E 'nodes|node|default_node'
ls -l /usr/share/passwall2/test.sh /usr/bin/timeout
uci -q get passwall2.rulenode.default_node
```

Выберите реальные ID из локальной конфигурации. Проверяйте каждый узел отдельно, пока текущий маршрут и доступ к управлению работают:

```sh
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node YOUR_PRIMARY_ID urltest_node
echo "EXIT_CODE=$?"
/usr/bin/timeout -k 2 15 /usr/share/passwall2/test.sh url_test_node YOUR_BACKUP_ID urltest_node
echo "EXIT_CODE=$?"
```

Ответ вида `204:0.35...` при коде завершения 0 означает успешную проверку. Пустой ответ сам по себе не доказывает блокировку сервера: дополнительно проверьте логи, DNS, WAN, Xray и сам тестовый скрипт PassWall2.

## 3. Изучите эталонные файлы

Файлы в `scripts/` — очищенные эталонные снимки, а не гарантированно точные копии текущих скриптов на роутере. Сравните их с файлами вашей версии PassWall2.

- `passwall2-failover` — оболочка режимов: принудительный выбор узла или запуск автоматической логики; необязательный вебхук HA.
- `passwall2-failover-core` — проверки, счётчики, правила решения и валидация после смены маршрута.
- `passwall2-failover-loop` — постоянный цикл и случайные интервалы.
- `passwall2-failover-watchdog.init` — служба procd.
- `passwall2-watchdog-probe-metrics.sh` — проверки для метрик в ручных режимах; маршрут не меняет.
- `passwall2-watchdog-publish-metrics.sh` — преобразует результат проверки в значения UCI.
- `passwall2-watchdog-publish-due.sh` — ограничивает частоту публикации метрик в автоматическом режиме.

Перед копированием адаптируйте путь проверки Xray, если в вашей системе он отличается.

## 4. Развёртывание без Home Assistant

Home Assistant необязателен: watchdog может работать через UCI и без HA. Однако пример оболочки содержит необязательный вызов вебхука. Для установки без HA удалите или закомментируйте только вызов `curl` вебхука в `set_status()`. Обновление статуса UCI можно оставить для локальной диагностики. Не оставляйте в опубликованном файле ни настоящий секрет, ни фальшивый токен, который могут принять за рабочий.

Перед включением:
1. Замените ID `PRIMARY` и `BACKUP` в ядре и оболочке.
2. Проверьте локальную команду PassWall2 и путь валидации Xray.
3. Убедитесь, что `_direct` действительно является корректной целью прямого подключения.
4. Проверьте сопоставление режимов и названия UCI-пакетов/секций.
5. Выполните `sh -n` для каждого скрипта.

После сравнения и адаптации файлы предполагаются к установке в следующие места:

| Файл репозитория | Путь на роутере |
|---|---|
| `scripts/passwall2-failover-core.sh` | `/usr/bin/passwall2-failover-core` |
| `scripts/passwall2-failover-loop.sh` | `/usr/bin/passwall2-failover-loop` |
| `scripts/passwall2-failover-watchdog.init` | `/etc/init.d/passwall2-failover-watchdog` |
| `scripts/passwall2-failover.sh.example` | `/usr/bin/passwall2-failover` после локальной адаптации |

Устанавливайте все три скрипта метрик вместе только после изучения их текущих эталонных версий и цепочки вызовов. Не заменяйте новую рабочую версию старым снимком вслепую.

```sh
chmod 755 /usr/bin/passwall2-failover-core /usr/bin/passwall2-failover-loop /usr/bin/passwall2-failover
chmod 755 /etc/init.d/passwall2-failover-watchdog
sh -n /usr/bin/passwall2-failover-core
sh -n /usr/bin/passwall2-failover
sh -n /usr/bin/passwall2-failover-loop
```

Включайте службу только после read-only-проверок и успешных изолированных тестов:

```sh
/etc/init.d/passwall2-failover-watchdog enable
/etc/init.d/passwall2-failover-watchdog start
/etc/init.d/passwall2-failover-watchdog status
```

Не запускайте одновременно старый cron-watchdog и службу procd: это два конкурирующих планировщика. В исходной установке строку `* * * * * /usr/bin/passwall2-failover` удалили, оставив ежедневное обновление подписки PassWall2. Не удаляйте другие cron-задания без необходимости.

## 5. Режимы UCI и состояние

```sh
uci show ha_watchdog
uci get passwall2.rulenode.default_node
```

Режимы:
- `auto` — автоматические решения по результатам проверок;
- `primary` — фиксированный основной узел, без автоматического переключения;
- `backup` — фиксированный резервный узел, без автоматического переключения;
- `off` — прямое подключение `_direct`, без автоматического переключения VPN.

В лабораторной установке режим находится в `ha_watchdog.main.mode`, статус — в `ha_watchdog.main.status`. Локальную схему UCI может потребоваться создать или адаптировать. Значение `auto` не означает, что само поле маршрута PassWall2 указывает на встроенную группу URLTest.

## 6. Телеметрия без HA

Если скрипты телеметрии установлены, проверьте значения:

```sh
uci show ha_watchdog_metrics
logread -e passwall2-watchdog-metrics | tail -n 20
```

Значения метрик остаются отложенными в UCI и не фиксируются во flash при каждой проверке. Они временные и после перезагрузки возвращаются к значениям по умолчанию до следующей публикации. В автоматическом режиме публикация ограничивается случайным интервалом примерно 180–300 секунд, но сами проверки узлов продолжаются на каждом цикле.

## 7. Подключение Home Assistant

Настраивайте интеграцию и помощники через интерфейс HA. Подробности о режиме, статусе, автоматизациях и вебхуке — в [документе Home Assistant](HOME-ASSISTANT.md). Не добавляйте реальный токен вебхука в репозиторий. Если HA не используется, этот раздел можно пропустить.

## 8. Проверки после включения

```sh
/etc/init.d/passwall2-failover-watchdog status
uci -q get ha_watchdog.main.mode
uci -q get ha_watchdog.main.status
uci -q get passwall2.rulenode.default_node
logread -e passwall2-watchdog | tail -n 40
```

Проверьте как минимум:
- служба запущена и включена в автозапуск;
- режим соответствует ожидаемому (`auto`, если требуется автоматика);
- ID активного маршрута не изменился неожиданно;
- логи показывают проверки обоих узлов;
- `last_check` метрик меняется только при срабатывании ограничителя публикации.

```sh
cat /tmp/passwall2-failover-state/metrics_last_publish 2>/dev/null
cat /tmp/passwall2-failover-state/metrics_interval 2>/dev/null
uci -q get ha_watchdog_metrics.nodes.last_check
```

## 9. Безопасность и откат

Не проверяйте отказ основного узла по удалённому подключению, если после переключения можете потерять доступ к роутеру. Контролируемый тест переключения и восстановления пока не подтверждён.

Если служба создаёт проблемы, можно остановить и отключить только её:

```sh
/etc/init.d/passwall2-failover-watchdog stop
/etc/init.d/passwall2-failover-watchdog disable
```

Это останавливает надзорную службу, но само по себе не восстанавливает маршрут и не обновляет состояние HA. После остановки отдельно проверьте текущий маршрут. Для прочих вариантов отката смотрите [резервные копии](BACKUPS.md).

