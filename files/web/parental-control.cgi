#!/bin/sh

CONFIG_FILE="/etc/parental-control/config.json"
LOG_FILE="/tmp/parental-control.log"

# Очищаем предыдущий лог
echo "=== NEW REQUEST ===" > "$LOG_FILE"
echo "Method: $REQUEST_METHOD" >> "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"

# Читаем все входные данные
if [ "$REQUEST_METHOD" = "POST" ]; then
    POST_DATA=$(dd bs=1M count=10 2>/dev/null)
    echo "Raw data (${#POST_DATA} bytes): $POST_DATA" >> "$LOG_FILE"
    
    # Проверка минимальной длины
    if [ ${#POST_DATA} -lt 2 ]; then
        echo '{"status":"error","message":"Empty data"}' >> "$LOG_FILE"
        echo "Content-Type: application/json"
        echo ""
        echo '{"status":"error","message":"Empty data"}'
        exit 1
    fi
    
    # Проверка JSON
    if ! echo "$POST_DATA" | jsonfilter -e '@' >/dev/null 2>&1; then
        echo '{"status":"error","message":"Invalid JSON"}' >> "$LOG_FILE"
        echo "Content-Type: application/json"
        echo ""
        echo '{"status":"error","message":"Invalid JSON"}'
        exit 1
    fi
    
    # Запись в файл
    echo "$POST_DATA" > "$CONFIG_FILE"
    echo '{"status":"success"}' >> "$LOG_FILE"
    echo "Content-Type: application/json"
    echo ""
    echo '{"status":"success"}'
    exit 0
fi

# GET запрос
echo "Content-Type: application/json"
echo ""
if [ -s "$CONFIG_FILE" ]; then
    cat "$CONFIG_FILE"
else
    echo '[]'
fi