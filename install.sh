#!/bin/bash

# --- Переменные конфигурации ---
BASE_URL="https://raw.githubusercontent.com/karkaradon/parental-control/main/files"

# Имена файлов
PARENTAL_CONTROL_SH="parental-control.sh"
CONFIG_JSON="config.json"
WEB_INDEX_HTML="index.html"
PARENTAL_CONTROL_CGI="parental-control.cgi"

# Директории на OpenWrt
TMP_DIR="/tmp"
WEB_ROOT_DIR="/www"
CGI_BIN_DIR="/www/cgi-bin"
PARENTAL_CONTROL_BASE_DIR="/etc/parental-control"
PARENTAL_CONTROL_WEB_DIR="/www/pctl"

# --- НОВЫЙ ФАЙЛ КОНФИГУРАЦИИ ДЛЯ ADGUARD ---
ADGUARD_CONFIG_FILE="$PARENTAL_CONTROL_BASE_DIR/adguard.conf"

# Файл cron для автозапуска
CRON_JOB="*/5 * * * * $PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH"


# --- Функции для вывода сообщений ---
log_info() {
    echo "INFO: $1"
    logger -t parental-control-installer "INFO: $1"
}

log_warning() {
    echo "WARNING: $1"
    logger -t parental-control-installer "WARNING: $1"
}

log_error() {
    echo "ERROR: $1"
    logger -t parental-control-installer "ERROR: $1"
    exit 1
}


# --- Начало установки ---
log_info "Начинаем установку родительского контроля OpenWrt..."

# 1. Обновляем пакеты и устанавливаем зависимости
log_info "Обновляем списки пакетов и устанавливаем необходимые зависимости: jsonfilter, jq, coreutils-paste..."
opkg update && opkg install jsonfilter jq coreutils-paste || log_error "Не удалось установить все зависимости. Проверьте подключение к интернету или наличие пакетов."

# 2. Создаем необходимые директории на роутере
log_info "Создаем необходимые директории..."
mkdir -p "$CGI_BIN_DIR" || log_error "Не удалось создать директорию $CGI_BIN_DIR"
mkdir -p "$PARENTAL_CONTROL_BASE_DIR" || log_error "Не удалось создать директорию $PARENTAL_CONTROL_BASE_DIR"
mkdir -p "$PARENTAL_CONTROL_WEB_DIR" || log_error "Не удалось создать директорию $PARENTAL_CONTROL_WEB_DIR"

# ==================== НАЧАЛО НОВОГО БЛОКА: ЗАПРОС ПАРАМЕТРОВ ADGUARD ====================
log_info "Пожалуйста, введите параметры для подключения к AdGuard Home."

read -p "Введите IP-адрес или хост AdGuard Home [127.0.0.1]: " adguard_host
AGH_HOST=${adguard_host:-"127.0.0.1"}

read -p "Введите порт AdGuard Home [3000]: " adguard_port
AGH_PORT=${adguard_port:-"3000"}

read -p "Введите имя пользователя AdGuard Home [admin]: " adguard_user
AGH_USER=${adguard_user:-"admin"}

# Безопасный ввод пароля (не отображается в консоли)
read -sp "Введите пароль для пользователя '$AGH_USER': " adguard_pass
echo "" # Перевод строки после ввода пароля

if [ -z "$adguard_pass" ]; then
    log_error "Пароль не может быть пустым. Установка прервана."
fi
AGH_PASS=$adguard_pass

# Создаем конфигурационный файл с полученными данными
log_info "Создание файла конфигурации $ADGUARD_CONFIG_FILE..."
cat << EOF > "$ADGUARD_CONFIG_FILE"
# Файл конфигурации AdGuard Home для скрипта родительского контроля
ADGUARD_HOST="${AGH_HOST}:${AGH_PORT}"
ADGUARD_USER="${AGH_USER}"
ADGUARD_PASS="${AGH_PASS}"
EOF

# Устанавливаем безопасные права на файл с паролем
chmod 600 "$ADGUARD_CONFIG_FILE" || log_warning "Не удалось установить права 600 на $ADGUARD_CONFIG_FILE"
log_info "Файл конфигурации AdGuard Home успешно создан."
# ==================== КОНЕЦ НОВОГО БЛОКА ====================


# 3. Скачиваем файлы
log_info "Скачиваем файлы скриптов..."
# ... (остальная часть скачивания файлов остается без изменений) ...
wget -O "$TMP_DIR/$PARENTAL_CONTROL_SH" "$BASE_URL/$PARENTAL_CONTROL_SH" && cp "$TMP_DIR/$PARENTAL_CONTROL_SH" "$PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH" || log_error "Ошибка загрузки/копирования $PARENTAL_CONTROL_SH"
wget -O "$TMP_DIR/$CONFIG_JSON" "$BASE_URL/$CONFIG_JSON" && cp "$TMP_DIR/$CONFIG_JSON" "$PARENTAL_CONTROL_BASE_DIR/$CONFIG_JSON" || log_error "Ошибка загрузки/копирования $CONFIG_JSON"
wget -O "$TMP_DIR/$PARENTAL_CONTROL_CGI" "$BASE_URL/web/$PARENTAL_CONTROL_CGI" && cp "$TMP_DIR/$PARENTAL_CONTROL_CGI" "$CGI_BIN_DIR/$PARENTAL_CONTROL_CGI" || log_error "Ошибка загрузки/копирования $PARENTAL_CONTROL_CGI"
wget -O "$TMP_DIR/$WEB_INDEX_HTML" "$BASE_URL/web/$WEB_INDEX_HTML" && cp "$TMP_DIR/$WEB_INDEX_HTML" "$PARENTAL_CONTROL_WEB_DIR/$WEB_INDEX_HTML" || log_error "Ошибка загрузки/копирования $WEB_INDEX_HTML"

# Очистка
rm -f "$TMP_DIR/$PARENTAL_CONTROL_SH" "$TMP_DIR/$CONFIG_JSON" "$TMP_DIR/$PARENTAL_CONTROL_CGI" "$TMP_DIR/$WEB_INDEX_HTML"


# 4. Устанавливаем права на файлы
# ... (этот блок без изменений) ...
log_info "Устанавливаем права на файлы..."
chmod +x "$PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH"
chmod +x "$CGI_BIN_DIR/$PARENTAL_CONTROL_CGI"
chmod 644 "$PARENTAL_CONTROL_BASE_DIR/$CONFIG_JSON"
chmod 644 "$PARENTAL_CONTROL_WEB_DIR/$WEB_INDEX_HTML"


# 5. Настраиваем автозапуск через крон
# ... (этот блок без изменений) ...
log_info "Настраиваем автозапуск родительского контроля через cron..."
(crontab -l 2>/dev/null | grep -v -F "$PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH"; echo "$CRON_JOB") | crontab - || log_error "Не удалось настроить cron-задание."


# 6. Проверяем доступность AdGuard Home (ИСПОЛЬЗУЯ НОВЫЕ ДАННЫЕ)
log_info "Проверяем доступность AdGuard Home по адресу http://${AGH_HOST}:${AGH_PORT}..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" \
     -m 5 \
     -u "$AGH_USER:$AGH_PASS" \
     "http://${AGH_HOST}:${AGH_PORT}/control/status")

if [ "$http_code" -eq 200 ]; then
    log_info "AdGuard Home доступен и учетные данные верны. Отлично!"
else
    log_warning "Не удалось подключиться к AdGuard Home (HTTP код: $http_code). Возможные причины:"
    log_warning " - Неверный IP-адрес или порт."
    log_warning " - Неверное имя пользователя или пароль."
    log_warning " - AdGuard Home не запущен или заблокирован файрволом."
    log_warning "Скрипт будет установлен, но функция блокировки доменов не будет работать до устранения проблемы."
fi


# 7. Перезагружаем веб-сервер uhttpd
# ... (остальные шаги без изменений) ...
log_info "Перезагружаем веб-сервер uhttpd для применения изменений..."
/etc/init.d/uhttpd restart || log_warning "Не удалось перезапустить uhttpd."

log_info "Определение IP-адреса роутера..."
ROUTER_IP=$(uci -q get network.lan.ipaddr)

if [ -z "$ROUTER_IP" ]; then
    log_warning "Не удалось автоматически определить IP-адрес роутера."
    echo "Установка завершена! Веб-интерфейс доступен по адресу: http://<IP_ВАШЕГО_РОУТЕРА>/pctl/"
else
    log_info "Установка завершена! Веб-интерфейс доступен по адресу: http://$ROUTER_IP/pctl/"
fi

log_info "Установка родительского контроля завершена успешно."
exit 0