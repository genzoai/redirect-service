#!/bin/bash
# Скрипт обновления базы данных GeoIP
# Автоматически вызывается через systemd timer раз в месяц

set -e

echo "=== GeoIP Database Update Started: $(date) ==="

# Путь к проекту
PROJECT_DIR="/opt/redirect"
LOG_FILE="/var/log/redirect-geoip-update.log"

# Переходим в директорию проекта
cd "$PROJECT_DIR"

# Логируем в файл
exec >> "$LOG_FILE" 2>&1

echo "Working directory: $(pwd)"

# Обновляем npm пакеты (включая geoip-lite)
echo "Updating geoip-lite database..."
npm update geoip-lite

# Проверяем версию базы данных
echo "Checking geoip-lite version..."
npm list geoip-lite || true

# Перезапускаем сервис для загрузки новой базы
echo "Restarting redirect service..."
systemctl restart redirect.service

# Проверяем статус
sleep 2
if systemctl is-active --quiet redirect.service; then
    echo "✅ Service restarted successfully"
    systemctl status redirect.service --no-pager
else
    echo "❌ Service failed to restart"
    systemctl status redirect.service --no-pager
    exit 1
fi

echo "=== GeoIP Database Update Completed: $(date) ==="
echo ""
