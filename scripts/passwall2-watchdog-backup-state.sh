#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

NEW="${1:-}"
STATE_DIR="/tmp/passwall2-failover-state"
FILE="$STATE_DIR/backup_config_state"
mkdir -p "$STATE_DIR" || exit 1

case "$NEW" in
    configured|not-configured|ambiguous) ;;
    *) echo "Usage: $0 configured|not-configured|ambiguous" >&2; exit 2 ;;
esac

OLD="$(cat "$FILE" 2>/dev/null)"
[ "$OLD" = "$NEW" ] && exit 0

case "$NEW" in
    not-configured)
        /usr/bin/passwall2-watchdog-event backup_missing "Резервный узел не настроен: в резервной подписке нет импортированного узла."
        ;;
    ambiguous)
        /usr/bin/passwall2-watchdog-event backup_ambiguous "Резервная подписка содержит несколько узлов; автоматический выбор резерва отключён."
        ;;
    configured)
        case "$OLD" in
            not-configured)
                /usr/bin/passwall2-watchdog-event backup_restored "Резервный узел снова появился в подписке; его ID определён автоматически."
                ;;
            ambiguous)
                /usr/bin/passwall2-watchdog-event backup_resolved "В резервной подписке снова найден ровно один узел."
                ;;
        esac
        ;;
esac

printf '%s\n' "$NEW" > "$FILE"
