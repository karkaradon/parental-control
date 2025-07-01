#!/bin/sh

# Раскомментируйте для подробной отладки. Будет выводить каждую выполняемую команду.
# set -x


CONFIG="/etc/parental-control/config.json"
TABLE="pc_table"
CHAIN="pc_devices_forward"

# ==================== НАЧАЛО БЛОКА ADGUARD HOME ====================

# http://192.168.10.1:3000
ADGUARD_HOST="127.0.0.1:3000"
ADGUARD_USER="admin"
ADGUARD_PASS="Adgpass@"

update_adguard_rules() {
    local rules_json="$1"
    
    log "Отправка новых правил в AdGuard Home..."
    # log "DEBUG JSON: $rules_json" # Раскомментируйте для отладки

    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
         -u "$ADGUARD_USER:$ADGUARD_PASS" \
         -X POST \
         -H "Content-Type: application/json" \
         -d "$rules_json" \
         "http://$ADGUARD_HOST/control/filtering/set_rules")
    
    if [ "$http_code" -eq 200 ]; then
        log "Правила в AdGuard Home успешно обновлены."
    else
        log "[!!!] ОШИБКА: AdGuard Home вернул код $http_code. Не удалось обновить правила."
    fi
}

# ==================== КОНЕЦ БЛОКА ADGUARD HOME ====================

log() {
    echo "$(date '+%F %T') - $1"
}

time_to_minutes() {
    echo "$1" | awk -F: '{print $1 * 60 + $2}'
}

# ==================== Инициализация nftables ====================
log "Очистка и создание таблицы nftables '$TABLE'"
nft delete table inet $TABLE 2>/dev/null || true
nft create table inet $TABLE
nft create chain inet $TABLE $CHAIN '{ type filter hook forward priority filter; policy drop; }'

# Получаем текущий день и время
current_day=$(date +%a | awk '{print tolower($0)}')
current_time=$(date +%H:%M)
current_minutes=$(time_to_minutes "$current_time")

log "Текущее время: $current_time ($current_minutes минут), день: $current_day"

# ==================== ИСПРАВЛЕННАЯ ЛОГИКА С ОБРАБОТКОЙ ВНУТРИ САБШЕЛЛА ====================

# Всю логику, работающую с результатами цикла, помещаем в одну группу команд { ... }
# Это гарантирует, что переменная adguard_rules_list будет доступна после цикла.
jq -c '.[]' "$CONFIG" | {
    
    # Инициализируем переменную ВНУТРИ группы команд
    adguard_rules_list=""

    while read -r user; do
        name=$(echo "$user" | jq -r '.name')
        devices=$(echo "$user" | jq -r '.devices[]')
        blocked_domains=$(echo "$user" | jq -r '.blocked_domains[]')

        allowed=false
        for period_json in $(echo "$user" | jq -c '.internet_access[]'); do
            days=$(echo "$period_json" | jq -r '.days[]' | awk '{print tolower($0)}')
            start_minutes=$(time_to_minutes "$(echo "$period_json" | jq -r '.start')")
            end_minutes=$(time_to_minutes "$(echo "$period_json" | jq -r '.end')")
            
            for day in $days; do
                if [ "$day" = "$current_day" ]; then
                    if [ "$start_minutes" -le "$end_minutes" ]; then
                        if [ "$current_minutes" -ge "$start_minutes" ] && [ "$current_minutes" -lt "$end_minutes" ]; then
                            allowed=true; break
                        fi
                    else
                        if [ "$current_minutes" -ge "$start_minutes" ] || [ "$current_minutes" -lt "$end_minutes" ]; then
                            allowed=true; break
                        fi
                    fi
                fi
            done
            [ "$allowed" = true ] && break
        done

        log "Пользователь '$name': доступ $([ "$allowed" = "true" ] && echo "РАЗРЕШЁН" || echo "ЗАПРЕЩЁН")"

        for mac in $devices; do
            ip=$(ip neigh show | grep -i "$mac" | awk '{print $1}' | head -n1)

            if [ -z "$ip" ]; then
                log "  Устройство $mac: оффлайн"
                continue
            fi
            
            log "  Устройство $mac ($ip): онлайн"

            if [ "$allowed" = "true" ]; then
                log "    -> Разрешаю интернет (nftables)"
                nft add rule inet $TABLE $CHAIN ip saddr "$ip" accept comment "PC_allow_${name}"

                if [ -n "$blocked_domains" ]; then
                    log "    -> Готовлю правила блокировки доменов для AdGuard:"
                    for domain in $blocked_domains; do
                        clean_domain=$(echo "$domain" | sed 's/\*\.//')
                        adguard_rule="||$clean_domain^\$client='$ip'"
                        log "      $adguard_rule"
                        
                        if [ -z "$adguard_rules_list" ]; then
                            adguard_rules_list="\"$adguard_rule\""
                        else
                            adguard_rules_list="$adguard_rules_list, \"$adguard_rule\""
                        fi
                    done
                fi
            else
                log "    -> Блокирую интернет (nftables)"
                nft add rule inet $TABLE $CHAIN ip saddr "$ip" drop comment "PC_deny_${name}"
            fi
        done
    done

    # ЭТА ЧАСТЬ ТЕПЕРЬ ВЫПОЛНЯЕТСЯ В ТОМ ЖЕ САБШЕЛЛЕ И "ВИДИТ" adguard_rules_list
    log "Проверка и отправка собранных правил в AdGuard..."
    if [ -n "$adguard_rules_list" ]; then
        final_json="{\"rules\": [ $adguard_rules_list ]}"
        update_adguard_rules "$final_json"
    else
        log "Нет активных правил для AdGuard. Очистка пользовательских правил."
        update_adguard_rules "{\"rules\": []}"
    fi

} # Конец группы команд

# ==================== КОНЕЦ ИСПРАВЛЕННОЙ ЛОГИКИ ====================

log "Разрешаю интернет для всех остальных (неуправляемых) устройств"
nft add rule inet "$TABLE" "$CHAIN" accept comment "PC_allow_others"

log "Финальные правила nftables в таблице '$TABLE':"
# nft list ruleset table inet $TABLE
# Новая, правильная строка:
nft list table inet $TABLE