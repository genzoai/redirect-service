# Миграция с Старой Версии (kaktus/redirect) на Новую (redirect_service)

## 📋 Обзор

Этот документ описывает процесс обновления production сервиса с `/opt/redirect/` (старая версия) на новую универсальную версию `/opt/redirect-service/`.

**Текущая версия на сервере:** `/opt/redirect/` (порт 3077)
**Новая версия:** `redirect_service/` (расширенная функциональность)

---

## 🎯 Цели миграции

1. ✅ Заменить старую версию на новую
2. ✅ Сохранить все данные и настройки
3. ✅ Обеспечить совместимость с n8n API
4. ✅ Минимизировать downtime
5. ✅ Получить новые возможности (HTML fetch, GeoIP, auto-update)

---

## ⚠️ Важная информация

### Что сохранится:
- ✅ Все данные в базе `redirect_db`
- ✅ Настройки сайтов (`sites.json`)
- ✅ UTM источники (`utm-sources.json`)
- ✅ SSL сертификаты
- ✅ Nginx конфигурация (с небольшими изменениями)
- ✅ Совместимость с n8n API (100%)

### Что изменится:
- 📦 Структура папок (новая организация)
- 📦 Имя systemd сервиса: `redirect.service` → `redirect-service.service`
- 📦 Расположение: `/opt/redirect/` → `/opt/redirect-service/`
- 📦 Новые зависимости (cheerio, axios для HTML fetch)

### Новые возможности:
- 🆕 Универсальный OG fetching (WordPress DB + HTML fetch)
- 🆕 Автоматическое обновление GeoIP базы
- 🆕 Система автообновлений с GitHub
- 🆕 Интерактивный установщик
- 🆕 Docker support
- 🆕 Расширенная документация

---

## 📝 Подготовка к миграции

### Шаг 1: Подключение к серверу

```bash
# Из локальной машины
ssh -i ~/.ssh/id_ed25519_KaktusSrvr root@91.98.69.196
# Passphrase: best dad ever
```

### Шаг 2: Проверка текущего состояния

```bash
# Проверить статус текущего сервиса
systemctl status redirect.service

# Проверить порт
ss -tlnp | grep 3077

# Посмотреть текущую структуру
ls -la /opt/redirect/

# Проверить nginx конфигурацию
cat /etc/nginx/sites-enabled/go.genzo.ai
```

### Шаг 3: Создание backup

```bash
# Backup приложения
sudo cp -r /opt/redirect /opt/redirect-backup-$(date +%Y%m%d-%H%M%S)

# Backup базы данных
mysqldump -u redirect_user -p redirect_db > /root/redirect-db-backup-$(date +%Y%m%d-%H%M%S).sql
# Пароль: your_secure_password_here

# Backup nginx конфигурации
sudo cp /etc/nginx/sites-available/go.genzo.ai /root/nginx-go.genzo.ai-backup-$(date +%Y%m%d-%H%M%S).conf

# Backup systemd сервиса
sudo cp /etc/systemd/system/redirect.service /root/redirect.service-backup-$(date +%Y%m%d-%H%M%S)
```

### Шаг 4: Сохранение текущих настроек

```bash
# Скопировать важные файлы для переноса
mkdir -p /root/migration-configs
cp /opt/redirect/.env /root/migration-configs/
cp /opt/redirect/config/sites.json /root/migration-configs/
cp /opt/redirect/config/utm-sources.json /root/migration-configs/
```

---

## 🚀 Процесс миграции

### Вариант А: Обновление (Рекомендуется)

Этот метод сохраняет старую версию как backup и устанавливает новую рядом.

#### 1. Остановить старый сервис

```bash
sudo systemctl stop redirect.service
sudo systemctl disable redirect.service
```

#### 2. Загрузить новую версию на сервер

**Из локальной машины:**
```bash
# Упаковать проект
cd /Users/anatoly/Renderfriends\ Dropbox/Anatoli\ Baidachny/Private/claude-code/
tar -czf redirect_service.tar.gz \
  --exclude='redirect_service/.git' \
  --exclude='redirect_service/node_modules' \
  --exclude='redirect_service/.DS_Store' \
  redirect_service/

# Загрузить на сервер
scp -i ~/.ssh/id_ed25519_KaktusSrvr redirect_service.tar.gz root@91.98.69.196:/root/
```

#### 3. Распаковать и установить на сервере

**На сервере:**
```bash
# Распаковать
cd /opt/
sudo tar -xzf /root/redirect_service.tar.gz
sudo mv redirect_service redirect-service

# Перенести настройки из старой версии
cd /opt/redirect-service

# Копировать .env
cp /root/migration-configs/.env config/.env

# Копировать sites.json
cp /root/migration-configs/sites.json config/sites.json

# Копировать utm-sources.json
cp /root/migration-configs/utm-sources.json config/utm-sources.json

# Установить зависимости
npm install --production
```

#### 4. Обновить конфигурацию

**Обновить .env (если нужно):**
```bash
nano config/.env
```

Проверить настройки:
```bash
PORT=3077
NODE_ENV=production

DB_HOST=127.0.0.1
DB_USER=redirect_user
DB_PASSWORD=your_secure_password_here
DB_NAME=redirect_db

WP_DB_HOST=127.0.0.1
WP_DB_USER=wp_readonly
WP_DB_PASSWORD=your_secure_password_here

API_TOKEN=your_secure_api_token_here
```

**Проверить sites.json:**
```bash
cat config/sites.json
```

Формат должен быть совместим. Если старый формат:
```json
{
  "realtruetales": {
    "domain": "realtruetales.com",
    "db": "realtruetales_db"
  }
}
```

Обновить на новый:
```json
{
  "realtruetales": {
    "domain": "realtruetales.com",
    "og_method": "wordpress_db",
    "wp_db": "realtruetales_db",
    "description": "Real True Tales"
  }
}
```

#### 5. Применить миграции базы данных (если есть новые)

```bash
# Проверить наличие новых миграций
cd /opt/redirect-service

# Применить миграцию для GeoIP (если еще не применена)
mysql -u redirect_user -p redirect_db < sql/04-add-country-field.sql
# Пароль: your_secure_password_here
```

#### 6. Настроить systemd сервис

```bash
# Создать новый systemd сервис
sudo cp config/systemd.example.service /etc/systemd/system/redirect-service.service

# Отредактировать если нужно
sudo nano /etc/systemd/system/redirect-service.service
```

Убедиться что пути правильные:
```ini
[Unit]
Description=Universal Redirect Service
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/redirect-service
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=10

Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

```bash
# Перезагрузить systemd
sudo systemctl daemon-reload

# Включить автозапуск
sudo systemctl enable redirect-service.service

# Запустить сервис
sudo systemctl start redirect-service.service

# Проверить статус
sudo systemctl status redirect-service.service
```

#### 7. Обновить Nginx конфигурацию (если нужно)

Проверить текущую конфигурацию:
```bash
cat /etc/nginx/sites-available/go.genzo.ai
```

Если нужно обновить:
```bash
sudo nano /etc/nginx/sites-available/go.genzo.ai
```

Базовая конфигурация должна остаться такой же (proxy на localhost:3077).

Перезагрузить nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

#### 8. Настроить GeoIP автообновление (опционально)

```bash
cd /opt/redirect-service

# Копировать systemd timer для GeoIP
sudo cp config/geoip-update.service /etc/systemd/system/
sudo cp config/geoip-update.timer /etc/systemd/system/

# Включить timer
sudo systemctl daemon-reload
sudo systemctl enable geoip-update.timer
sudo systemctl start geoip-update.timer

# Проверить статус
sudo systemctl status geoip-update.timer
```

#### 9. Тестирование

```bash
# Health check
curl http://localhost:3077/health

# Проверить редирект
curl -I "https://go.genzo.ai/go/fb/realtruetales/test-article"

# Проверить OG preview (как бот)
curl -A "facebookexternalhit/1.1" "https://go.genzo.ai/go/fb/realtruetales/test-article"

# Проверить API статистики
curl -H "Authorization: Bearer your_secure_api_token_here" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week"
```

#### 10. Мониторинг логов

```bash
# Следить за логами
sudo journalctl -u redirect-service.service -f

# Последние 100 строк
sudo journalctl -u redirect-service.service -n 100
```

---

### Вариант Б: Полная замена

Этот метод полностью удаляет старую версию и заменяет на новую.

**⚠️ Убедитесь что backup создан!**

```bash
# 1. Остановить и удалить старый сервис
sudo systemctl stop redirect.service
sudo systemctl disable redirect.service
sudo rm /etc/systemd/system/redirect.service

# 2. Переименовать старую папку
sudo mv /opt/redirect /opt/redirect-old

# 3. Следовать шагам из Варианта А (начиная с пункта 2)
```

---

## 🔄 Откат (Rollback)

Если что-то пошло не так:

### Быстрый откат

```bash
# 1. Остановить новый сервис
sudo systemctl stop redirect-service.service
sudo systemctl disable redirect-service.service

# 2. Восстановить старый сервис
sudo systemctl enable redirect.service
sudo systemctl start redirect.service

# 3. Проверить
sudo systemctl status redirect.service
curl http://localhost:3077/health
```

### Полный откат с восстановлением

```bash
# Остановить новый сервис
sudo systemctl stop redirect-service.service

# Удалить новый
sudo rm -rf /opt/redirect-service

# Восстановить из backup
sudo cp -r /opt/redirect-backup-YYYYMMDD-HHMMSS /opt/redirect

# Восстановить БД (если нужно)
mysql -u redirect_user -p redirect_db < /root/redirect-db-backup-YYYYMMDD-HHMMSS.sql

# Запустить старый сервис
sudo systemctl start redirect.service
```

---

## ✅ Проверочный чеклист после миграции

- [ ] Сервис запущен: `systemctl status redirect-service.service`
- [ ] Health check работает: `curl http://localhost:3077/health`
- [ ] Редиректы работают: протестировать реальный URL
- [ ] OG preview работает: протестировать с User-Agent бота
- [ ] API статистики работает: протестировать с Bearer token
- [ ] Логи чистые: нет ошибок в `journalctl -u redirect-service.service -n 100`
- [ ] Nginx работает: `sudo nginx -t && sudo systemctl status nginx`
- [ ] SSL работает: `curl https://go.genzo.ai/health`
- [ ] GeoIP работает: проверить что `country` заполняется в БД
- [ ] Автозапуск включен: `systemctl is-enabled redirect-service.service`

---

## 📊 Мониторинг после миграции

### Первые 24 часа

```bash
# Следить за логами
sudo journalctl -u redirect-service.service -f

# Проверять базу данных
mysql -u redirect_user -p redirect_db -e "SELECT COUNT(*) as total_clicks FROM clicks WHERE created_at > NOW() - INTERVAL 1 HOUR;"

# Проверять Nginx логи
tail -f /var/log/nginx/go.genzo.ai-access.log
tail -f /var/log/nginx/go.genzo.ai-error.log
```

### Статистика

```bash
# Количество кликов за сегодня
mysql -e "SELECT COUNT(*) FROM clicks WHERE DATE(created_at) = CURDATE();" redirect_db

# По странам (проверка GeoIP)
mysql -e "SELECT country, COUNT(*) as count FROM clicks WHERE DATE(created_at) = CURDATE() GROUP BY country ORDER BY count DESC LIMIT 10;" redirect_db

# По типам (click vs preview)
mysql -e "SELECT type, COUNT(*) FROM clicks WHERE DATE(created_at) = CURDATE() GROUP BY type;" redirect_db
```

---

## 🗑️ Очистка (после успешной миграции)

**Выполнять только после 1-2 недель стабильной работы!**

```bash
# Удалить старую версию
sudo rm -rf /opt/redirect-old

# Удалить старые backups (оставить последний)
ls -t /opt/redirect-backup-* | tail -n +2 | xargs sudo rm -rf

# Удалить старые DB backups (оставить последний)
ls -t /root/redirect-db-backup-* | tail -n +2 | xargs rm -f

# Удалить старый systemd backup
rm /root/redirect.service-backup-*
```

---

## 📞 Поддержка и troubleshooting

### Проблемы с подключением к БД

```bash
# Проверить доступ
mysql -u redirect_user -p -h 127.0.0.1 redirect_db

# Проверить права
mysql -e "SHOW GRANTS FOR 'redirect_user'@'localhost';"
```

### Сервис не запускается

```bash
# Посмотреть подробные логи
sudo journalctl -u redirect-service.service -xe

# Проверить синтаксис Node.js
cd /opt/redirect-service
node src/server.js
```

### Nginx ошибки

```bash
# Проверить конфигурацию
sudo nginx -t

# Посмотреть логи ошибок
tail -n 50 /var/log/nginx/error.log
```

---

## 📚 Дополнительные ресурсы

- [README.md](README.md) - Общая документация
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Деплой
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) - Конфигурация
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Решение проблем
- [docs/API.md](docs/API.md) - API документация

---

**Автор:** Claude Code
**Дата:** 2026-01-13
**Версия:** 1.0
