# GeoIP Setup - Определение страны по IP

> **Входит в Universal Redirect Service по умолчанию**
> GeoIP tracking включен и настроен автоматически при использовании установщика.

---

## Возможности

✅ **Автоматическое определение страны** по IP каждого клика
✅ **База MaxMind GeoLite2** - точность ~99% для стран
✅ **Автообновление** базы данных (1 раз в месяц)
✅ **Статистика по странам** в API
✅ **ISO коды стран** (US, UA, PL, ES и т.д.)

---

## Как это работает

1. При каждом клике определяется IP пользователя
2. IP lookup в локальной базе GeoLite2 (~50MB)
3. Страна сохраняется в БД (поле `country`)
4. Доступна в API статистики

**Скорость:** ~1-2ms на определение (локальная база, без HTTP запросов)

---

## Установка

### Автоматическая установка (рекомендуется)

```bash
# Запустить установщик
sudo bash scripts/install.sh
```

Установщик автоматически:
- ✅ Установит geoip-lite
- ✅ Скачает базу GeoIP
- ✅ Добавит поле country в БД
- ✅ Настроит автообновление

### Ручная установка

Если вы устанавливали сервис вручную, выполните:

#### 1. Установить зависимость

```bash
cd /opt/redirect  # или ваша директория установки
npm install
```

Это установит `geoip-lite` и автоматически скачает базу данных GeoIP (~50MB).

#### 2. Выполнить миграцию базы данных

```bash
mysql -u root -p redirect_db < sql/04-add-country-field.sql
```

**Проверить, что поле добавлено:**
```bash
mysql -e "DESCRIBE redirect_db.clicks;"
```

Должно быть поле `country VARCHAR(2) NULL` после `ip`.

#### 3. Настроить автообновление GeoIP

**Сделать скрипт исполняемым:**
```bash
chmod +x scripts/update-geoip.sh
```

**Установить systemd service и timer:**
```bash
# Копировать файлы в systemd
cp config/geoip-update.service /etc/systemd/system/
cp config/geoip-update.timer /etc/systemd/system/

# Перезагрузить systemd
systemctl daemon-reload

# Включить и запустить timer
systemctl enable geoip-update.timer
systemctl start geoip-update.timer

# Проверить статус
systemctl status geoip-update.timer
```

**Проверить, когда следующее обновление:**
```bash
systemctl list-timers geoip-update.timer
```

#### 4. Перезапустить redirect сервис

```bash
systemctl restart redirect.service
systemctl status redirect.service
```

---

## Проверка работы

**Тестовый запрос:**
```bash
curl -i "https://go.yourdomain.com/go/fb/mysite/article-slug"
```

**Проверить в базе данных:**
```bash
mysql -e "SELECT ip, country, source, site, article_id, created_at FROM redirect_db.clicks ORDER BY created_at DESC LIMIT 10;"
```

Должны появиться записи с заполненным полем `country` (например: `UA`, `US`, `PL`).

## Логи

**Логи redirect сервиса:**
```bash
journalctl -u redirect.service -f
```

**Логи обновления GeoIP:**
```bash
tail -f /var/log/redirect-geoip-update.log
```

**Логи systemd timer:**
```bash
journalctl -u geoip-update.service -f
```

## Ручное обновление GeoIP

Если нужно обновить базу вручную (не дожидаясь таймера):

```bash
# Вызвать скрипт напрямую
/opt/redirect/scripts/update-geoip.sh

# Или через systemd
systemctl start geoip-update.service
```

## Расписание обновлений

Timer настроен на запуск:
- **1-го числа каждого месяца** в 03:00
- **Через 5 минут** после загрузки сервера (первый раз)

MaxMind обновляет GeoLite2 базу **каждый первый вторник месяца**, поэтому наше обновление 1-го числа будет гарантировать свежие данные.

## Статистика по странам

Теперь можно делать запросы вида:

```sql
-- Топ стран за неделю
SELECT country, COUNT(*) as clicks
FROM redirect_db.clicks
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
  AND type = 'click'
  AND country IS NOT NULL
GROUP BY country
ORDER BY clicks DESC
LIMIT 10;

-- Статистика по сайту и стране
SELECT site, country, COUNT(*) as clicks
FROM redirect_db.clicks
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
  AND type = 'click'
GROUP BY site, country
ORDER BY site, clicks DESC;
```

## Troubleshooting

### База GeoIP не загрузилась

```bash
# Проверить размер базы
ls -lh /opt/redirect/node_modules/geoip-lite/data/

# Переустановить geoip-lite
cd /opt/redirect
npm uninstall geoip-lite
npm install geoip-lite
```

### Поле country остается NULL

**Возможные причины:**
1. IP локальный (127.0.0.1, 192.168.x.x) - не определяется
2. IP неверный формат - проверить логи
3. База GeoIP не загружена - переустановить пакет

**Проверка:**
```bash
# Логи redirect сервиса
journalctl -u redirect.service -n 50

# Проверить IP в запросе
mysql -e "SELECT ip, country FROM redirect_db.clicks WHERE country IS NULL LIMIT 10;"
```

---

**Дата:** 2026-01-12
**Автор:** Claude Code
**Версия:** 1.0
