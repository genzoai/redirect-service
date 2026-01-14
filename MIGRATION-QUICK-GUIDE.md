# Быстрая миграция - Шпаргалка

## 🎯 Цель
Обновить `/opt/redirect/` → `/opt/redirect-service/` на сервере `91.98.69.196`

---

## 📋 Пошаговая инструкция

### 1️⃣ Подготовка (на локальной машине)

```bash
# Упаковать проект
cd "/Users/anatoly/Renderfriends Dropbox/Anatoli Baidachny/Private/claude-code/"
tar -czf redirect_service.tar.gz \
  --exclude='redirect_service/.git' \
  --exclude='redirect_service/node_modules' \
  --exclude='redirect_service/.DS_Store' \
  redirect_service/

# Загрузить на сервер
scp -i ~/.ssh/id_ed25519_KaktusSrvr redirect_service.tar.gz root@91.98.69.196:/root/
# Passphrase: best dad ever
```

### 2️⃣ Подключение к серверу

```bash
ssh -i ~/.ssh/id_ed25519_KaktusSrvr root@91.98.69.196
# Passphrase: best dad ever
```

### 3️⃣ Backup (на сервере)

```bash
# Backup приложения
cp -r /opt/redirect /opt/redirect-backup-$(date +%Y%m%d-%H%M%S)

# Backup базы
mysqldump -u redirect_user -pyour_secure_password_here redirect_db > /root/redirect-db-backup-$(date +%Y%m%d-%H%M%S).sql

# Сохранить настройки
mkdir -p /root/migration-configs
cp /opt/redirect/.env /root/migration-configs/
cp /opt/redirect/config/sites.json /root/migration-configs/
cp /opt/redirect/config/utm-sources.json /root/migration-configs/
```

### 4️⃣ Остановить старый сервис

```bash
systemctl stop redirect.service
systemctl disable redirect.service
```

### 5️⃣ Установка новой версии

```bash
# Распаковать
cd /opt/
tar -xzf /root/redirect_service.tar.gz
mv redirect_service redirect-service

# Перенести настройки
cd /opt/redirect-service
cp /root/migration-configs/.env config/.env
cp /root/migration-configs/sites.json config/sites.json
cp /root/migration-configs/utm-sources.json config/utm-sources.json

# Установить зависимости
npm install --production
```

### 6️⃣ Настроить systemd

```bash
# Создать сервис
cp /opt/redirect-service/config/systemd.example.service /etc/systemd/system/redirect-service.service

# Убедиться что WorkingDirectory=/opt/redirect-service
nano /etc/systemd/system/redirect-service.service

# Запустить
systemctl daemon-reload
systemctl enable redirect-service.service
systemctl start redirect-service.service
```

### 7️⃣ Проверка

```bash
# Статус
systemctl status redirect-service.service

# Health check
curl http://localhost:3002/health

# Редирект (замените test-article на реальный)
curl -I "https://go.genzo.ai/go/fb/realtruetales/test-article"

# API
curl -H "Authorization: Bearer your_secure_api_token_here" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week"

# Логи
journalctl -u redirect-service.service -n 50
```

---

## 🔄 Откат (если проблемы)

```bash
# Остановить новый
systemctl stop redirect-service.service
systemctl disable redirect-service.service

# Запустить старый
systemctl enable redirect.service
systemctl start redirect.service

# Проверить
systemctl status redirect.service
curl http://localhost:3002/health
```

---

## ✅ Чеклист проверки

- [ ] `systemctl status redirect-service.service` - Active (running)
- [ ] `curl http://localhost:3002/health` - {"status":"ok"}
- [ ] Редирект работает (протестировать реальный URL)
- [ ] API работает (протестировать с Bearer token)
- [ ] Логи без ошибок: `journalctl -u redirect-service.service -n 100`

---

## 📝 Важные команды

```bash
# Логи в реальном времени
journalctl -u redirect-service.service -f

# Перезапуск
systemctl restart redirect-service.service

# Статистика БД
mysql -u redirect_user -pyour_secure_password_here redirect_db \
  -e "SELECT COUNT(*) FROM clicks WHERE created_at > NOW() - INTERVAL 1 HOUR;"
```

---

## 🔗 Полная документация

См. `MIGRATION-FROM-OLD-VERSION.md` для детальной информации
