#!/bin/bash

# --- Переменные конфигурации ---
BASE_URL="https://raw.githubusercontent.com/karkaradon/parental-control/main/files" # Пример для прямого скачивания из ветки 'main'

# Имена файлов (соответствуют структуре на GitHub)
INSTALL_SCRIPT_NAME="install.sh"
PARENTAL_CONTROL_SH="parental-control.sh"
CONFIG_JSON="config.json"
WEB_INDEX_HTML="index.html"
# WEB_STYLE_CSS="style.css" # Если будет CSS
PARENTAL_CONTROL_CGI="parental-control.cgi"

# Директории на OpenWrt
TMP_DIR="/tmp"
WEB_ROOT_DIR="/www"
CGI_BIN_DIR="/www/cgi-bin"
PARENTAL_CONTROL_BASE_DIR="/etc/parental-control"
PARENTAL_CONTROL_WEB_DIR="/www/pctl" # Новая директория для HTML

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
log_info "Обновляем списки пакетов и устанавливаем необходимые зависимости: jsonfilter, dnsutils, jq, coreutils-paste..."
opkg update && opkg install jsonfilter jq coreutils-paste || log_error "Не удалось установить все зависимости. Проверьте подключение к интернету или наличие пакетов."

# 2. Создаем необходимые директории на роутере
log_info "Создаем необходимые директории: $CGI_BIN_DIR, $PARENTAL_CONTROL_BASE_DIR, $PARENTAL_CONTROL_WEB_DIR..."
mkdir -p "$CGI_BIN_DIR" || log_error "Не удалось создать директорию $CGI_BIN_DIR"
mkdir -p "$PARENTAL_CONTROL_BASE_DIR" || log_error "Не удалось создать директорию $PARENTAL_CONTROL_BASE_DIR"
mkdir -p "$PARENTAL_CONTROL_WEB_DIR" || log_error "Не удалось создать директорию $PARENTAL_CONTROL_WEB_DIR"

# 3. Скачиваем файлы в /tmp и копируем их на место
log_info "Скачиваем файлы в $TMP_DIR и копируем в целевые директории..."

# Скачиваем скрипт родительского контроля
log_info "Скачиваем $PARENTAL_CONTROL_SH..."
wget -O "$TMP_DIR/$PARENTAL_CONTROL_SH" "$BASE_URL/$PARENTAL_CONTROL_SH" || log_error "Не удалось скачать $PARENTAL_CONTROL_SH"
cp "$TMP_DIR/$PARENTAL_CONTROL_SH" "$PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH" || log_error "Не удалось скопировать $PARENTAL_CONTROL_SH"

# Скачиваем файл конфигурации JSON
log_info "Скачиваем $CONFIG_JSON..."
wget -O "$TMP_DIR/$CONFIG_JSON" "$BASE_URL/$CONFIG_JSON" || log_error "Не удалось скачать $CONFIG_JSON"
cp "$TMP_DIR/$CONFIG_JSON" "$PARENTAL_CONTROL_BASE_DIR/$CONFIG_JSON" || log_error "Не удалось скопировать $CONFIG_JSON"

# Скачиваем CGI-скрипт (он находится в files/web/parental-control.cgi)
log_info "Скачиваем $PARENTAL_CONTROL_CGI..."
wget -O "$TMP_DIR/$PARENTAL_CONTROL_CGI" "$BASE_URL/web/$PARENTAL_CONTROL_CGI" || log_error "Не удалось скачать $PARENTAL_CONTROL_CGI"
cp "$TMP_DIR/$PARENTAL_CONTROL_CGI" "$CGI_BIN_DIR/$PARENTAL_CONTROL_CGI" || log_error "Не удалось скопировать $PARENTAL_CONTROL_CGI"

# Скачиваем index.html (он находится в files/web/index.html)
log_info "Скачиваем $WEB_INDEX_HTML..."
wget -O "$TMP_DIR/$WEB_INDEX_HTML" "$BASE_URL/web/$WEB_INDEX_HTML" || log_error "Не удалось скачать $WEB_INDEX_HTML"
cp "$TMP_DIR/$WEB_INDEX_HTML" "$PARENTAL_CONTROL_WEB_DIR/$WEB_INDEX_HTML" || log_error "Не удалось скопировать $WEB_INDEX_HTML"

# Если есть style.css
# log_info "Скачиваем $WEB_STYLE_CSS..."
# wget -O "$TMP_DIR/$WEB_STYLE_CSS" "$BASE_URL/web/$WEB_STYLE_CSS" || log_error "Не удалось скачать $WEB_STYLE_CSS"
# cp "$TMP_DIR/$WEB_STYLE_CSS" "$PARENTAL_CONTROL_WEB_DIR/$WEB_STYLE_CSS" || log_error "Не удалось скопировать $WEB_STYLE_CSS"

# Удаляем временные файлы
log_info "Очистка временных файлов в $TMP_DIR..."
rm -f "$TMP_DIR/$PARENTAL_CONTROL_SH"
rm -f "$TMP_DIR/$CONFIG_JSON"
rm -f "$TMP_DIR/$PARENTAL_CONTROL_CGI"
rm -f "$TMP_DIR/$WEB_INDEX_HTML"
# rm -f "$TMP_DIR/$WEB_STYLE_CSS" # Если есть CSS

# 4. Устанавливаем права на файлы
log_info "Устанавливаем права на файлы..."
chmod +x "$PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH" || log_error "Не удалось установить права на $PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH"
chmod +x "$CGI_BIN_DIR/$PARENTAL_CONTROL_CGI" || log_error "Не удалось установить права на $CGI_BIN_DIR/$PARENTAL_CONTROL_CGI"
chmod 644 "$PARENTAL_CONTROL_BASE_DIR/$CONFIG_JSON" || log_error "Не удалось установить права на $PARENTAL_CONTROL_BASE_DIR/$CONFIG_JSON"
chmod 644 "$PARENTAL_CONTROL_WEB_DIR/$WEB_INDEX_HTML" || log_error "Не удалось установить права на $PARENTAL_CONTROL_WEB_DIR/$WEB_INDEX_HTML"
# chmod 644 "$PARENTAL_CONTROL_WEB_DIR/$WEB_STYLE_CSS" # Если есть CSS

# 5. Настраиваем автозапуск через крон
log_info "Настраиваем автозапуск родительского контроля через cron..."
(crontab -l 2>/dev/null | grep -v -F "$PARENTAL_CONTROL_BASE_DIR/$PARENTAL_CONTROL_SH"; echo "$CRON_JOB") | crontab - || log_error "Не удалось настроить cron-задание."
log_info "Cron-задание добавлено: '$CRON_JOB'"

# 6. Проверяем доступность AdGuard Home (127.0.0.1:3000)
log_info "Проверяем доступность AdGuard Home (127.0.0.1:3000)..."

# Функция проверки AdGuard Home
check_adguard() {
    # Проверка через статус службы (если скрипт существует)
    if [ -f /etc/init.d/adguardhome ]; then
        if /etc/init.d/adguardhome status >/dev/null 2>&1; then
            log_info "Служба AdGuard Home запущена"
            return 0
        else
            log_warning "Служба AdGuard Home существует, но не запущена"
            return 1
        fi
    fi

    # Проверка через HTTP-ответ (302 + /login.html)
    if RESPONSE=$(curl -s -I -m 2 "http://127.0.0.1:3000" 2>/dev/null) && \
       echo "$RESPONSE" | grep -q "302 Found" && \
       echo "$RESPONSE" | grep -q "Location: /login.html"; then
        log_info "Обнаружен AdGuard Home (перенаправление на /login.html)"
        return 0
    fi

    return 2
}

# Основная проверка
if check_adguard; then
    log_info "AdGuard Home (127.0.0.1:3000) доступен. Отлично!"
else
    log_warning "AdGuard Home (127.0.0.1:3000) недоступен. Убедитесь, что он установлен и запущен, так как он может быть необходим для работы родительского контроля."
fi

# 7. Перезагружаем веб-сервер uhttpd
log_info "Перезагружаем веб-сервер uhttpd для применения изменений..."
/etc/init.d/uhttpd restart || log_warning "Не удалось перезапустить uhttpd. Возможно, он не запущен или произошла ошибка."

# 8. Определяем IP адрес роутера и сообщаем о доступе к интерфейсу
log_info "Определение IP-адреса роутера для доступа к веб-интерфейсу..."
ROUTER_IP=$(uci -q get network.lan.ipaddr)

if [ -z "$ROUTER_IP" ]; then
    log_warning "Не удалось автоматически определить IP-адрес роутера. Используйте IP-адрес, по которому вы обычно заходите на роутер."
    echo "Установка завершена! Веб-интерфейс для настройки родительского контроля доступен по адресу: http://<IP_ВАШЕГО_РОУТЕРА>/pctl/index.html"
else
    log_info "Установка завершена! Веб-интерфейс для настройки родительского контроля доступен по адресу: http://$ROUTER_IP/pctl/"
fi

log_info "Установка родительского контроля завершена успешно."
log_info "Проверьте логи для получения дополнительной информации: logread | grep parental-control-installer"

exit 0