# Инструкции по настройке Redirect Service

## Как подключить новый источник (source)

Текущие источники: `fb`, `tg`, `ig`, `email`

### Шаги для добавления нового источника (например, LinkedIn):

#### 1. Добавить в словарь UTM меток

Файл: `/opt/redirect/config/utm-sources.json`

```json
{
  "fb": "utm_source=facebook&utm_medium=comment",
  "tg": "utm_source=telegram&utm_medium=message",
  "ig": "utm_source=instagram&utm_medium=story",
  "email": "utm_source=email&utm_medium=newsletter",
  "linkedin": "utm_source=linkedin&utm_medium=post"
}
```

**Формат UTM меток:**
- `utm_source` - источник трафика (linkedin, twitter, tiktok, etc.)
- `utm_medium` - тип размещения (post, story, ad, etc.)
- `utm_campaign` - кампания = articleId

#### 2. Перезапустить сервис

```bash
systemctl restart redirect.service
```

#### 3. Проверить работу

```bash
# Тест редиректа
curl -i "https://go.genzo.ai/go/linkedin/realtruetales/ARTICLE_SLUG"

# Должен вернуть:
# location: https://realtruetales.com/ARTICLE_SLUG/?utm_source=linkedin&utm_medium=post&utm_campaign=auto
```

### Настройка определения бота (опционально)

Если у нового источника есть свой бот для preview (например, LinkedInBot), добавить в bot-detector.

Файл: `/opt/redirect/middleware/bot-detector.js`

Найти массив `botPatterns` и добавить:

```javascript
const botPatterns = [
  'facebookexternalhit',
  'Facebot',
  'Twitterbot',
  'TelegramBot',
  'LinkedInBot',  // <- Добавить
  // ...
];
```

Перезапустить сервис:

```bash
systemctl restart redirect.service
```

---

## Как подключить новый сайт

Текущие сайты: `realtruetales`, `rozpovediserdza`, `nathnenne`, `radoscz`

### Шаги для добавления нового сайта (например, newsample.com):

#### 1. Добавить сайт в конфигурацию

Файл: `/opt/redirect/config/sites.json`

```json
{
  "realtruetales": {
    "domain": "realtruetales.com",
    "db": "realtruetales_db"
  },
  "rozpovediserdza": {
    "domain": "rozpovediserdza.com",
    "db": "rozpovediserdza_db"
  },
  "nathnenne": {
    "domain": "nathnenne.com",
    "db": "wp_nathnenne"
  },
  "radoscz": {
    "domain": "radoscz.com",
    "db": "radoscz_db"
  },
  "newsample": {
    "domain": "newsample.com",
    "db": "newsample_db"
  }
}
```

**Параметры:**
- **Ключ** (`newsample`) - короткое название для URL
- **domain** - полный домен сайта
- **db** - название базы данных WordPress

#### 2. Выдать права read-only пользователю на новую БД

```bash
mysql -e "GRANT SELECT ON newsample_db.* TO 'wp_readonly'@'localhost'; FLUSH PRIVILEGES;"
```

Проверить доступ:

```bash
mysql -u wp_readonly -p -e "SHOW TABLES FROM newsample_db;"
```

#### 3. Перезапустить сервис

```bash
systemctl restart redirect.service
```

#### 4. Проверить работу

```bash
# Получить slug любой статьи из новой БД
mysql -e "SELECT post_name FROM newsample_db.wp_posts WHERE post_type='post' AND post_status='publish' LIMIT 1;"

# Тест редиректа
curl -i "https://go.genzo.ai/go/fb/newsample/ARTICLE_SLUG"

# Тест OG preview (как бот)
curl -A "facebookexternalhit/1.1" "https://go.genzo.ai/go/fb/newsample/ARTICLE_SLUG"

# Должен вернуть HTML с OG тегами
```

#### 5. Проверить логирование

```bash
mysql -e "SELECT * FROM redirect_db.clicks WHERE site='newsample' ORDER BY created_at DESC LIMIT 5;"
```

---

## Изменение существующих UTM меток

### Если нужно изменить UTM метки для существующего источника:

#### 1. Редактировать utm-sources.json

Файл: `/opt/redirect/config/utm-sources.json`

Пример - изменить кампанию для Facebook:

```json
{
  "fb": "utm_source=facebook&utm_medium=comment&utm_campaign=promo2026",
  ...
}
```

#### 2. Перезапустить сервис

```bash
systemctl restart redirect.service
```

#### 3. Проверить новые метки

```bash
curl -i "https://go.genzo.ai/go/fb/realtruetales/ARTICLE_SLUG" | grep location
# location: https://realtruetales.com/ARTICLE_SLUG/?utm_source=facebook&utm_medium=comment&utm_campaign=promo2026
```

---

## Изменение домена существующего сайта

### Если сайт переехал на новый домен:

#### 1. Обновить sites.json

Файл: `/opt/redirect/config/sites.json`

```json
{
  "realtruetales": {
    "domain": "newdomain.com",  // <- Изменить
    "db": "realtruetales_db"
  }
}
```

#### 2. Перезапустить сервис

```bash
systemctl restart redirect.service
```

#### 3. Проверить редиректы

```bash
curl -i "https://go.genzo.ai/go/fb/realtruetales/ARTICLE_SLUG"
# Должен редиректить на newdomain.com
```

---

## Удаление сайта или источника

### Удаление источника

1. Удалить запись из `/opt/redirect/config/utm-sources.json`
2. Перезапустить сервис: `systemctl restart redirect.service`
3. Старые ссылки с этим source вернут `404 - Unknown source`

### Удаление сайта

1. Удалить запись из `/opt/redirect/config/sites.json`
2. Отозвать права у wp_readonly:
   ```bash
   mysql -e "REVOKE SELECT ON sitedb.* FROM 'wp_readonly'@'localhost'; FLUSH PRIVILEGES;"
   ```
3. Перезапустить сервис: `systemctl restart redirect.service`
4. Старые ссылки вернут `404 - Unknown site`

**Важно:** Данные в таблице `clicks` остаются и можно получить историческую статистику.

---

## Резервное копирование конфигурации

### Перед внесением изменений:

```bash
# Создать бэкап конфигурации
cd /opt/redirect/config
cp utm-sources.json utm-sources.json.backup
cp sites.json sites.json.backup
```

### Восстановление из бэкапа:

```bash
cd /opt/redirect/config
cp utm-sources.json.backup utm-sources.json
cp sites.json.backup sites.json
systemctl restart redirect.service
```

---

## Мониторинг и диагностика

### Проверка доступности всех сайтов

```bash
# Скрипт для проверки доступа к WordPress БД
for site in realtruetales_db rozpovediserdza_db wp_nathnenne radoscz_db; do
  echo "Checking $site..."
  mysql -u wp_readonly -p -e "SELECT COUNT(*) FROM $site.wp_posts WHERE post_type='post';" 2>/dev/null && echo "✅ OK" || echo "❌ FAILED"
done
```

### Проверка работы всех источников

```bash
# Получить slug статьи
SLUG="t95buwa"

# Тест каждого источника
for source in fb tg ig email; do
  echo "Testing $source..."
  curl -i "https://go.genzo.ai/go/$source/realtruetales/$SLUG" 2>&1 | grep "location:"
done
```

### Просмотр статистики по источникам

```bash
mysql -e "
  SELECT source, COUNT(*) as clicks
  FROM redirect_db.clicks
  WHERE type='click'
  GROUP BY source
  ORDER BY clicks DESC;
"
```

---

## Частые вопросы

**Q: Можно ли использовать несколько доменов для одного сайта?**

A: Нет, в текущей версии один ключ = один домен. Но можно добавить второй ключ для того же сайта:

```json
{
  "realtruetales": {
    "domain": "realtruetales.com",
    "db": "realtruetales_db"
  },
  "realtruetales-alt": {
    "domain": "alternative-domain.com",
    "db": "realtruetales_db"
  }
}
```

**Q: Можно ли добавить динамические UTM параметры?**

A: UTM метки статичны для каждого source. Если нужна гибкость - можно создать несколько источников, но динамична по отношения к постам, код добавляет utm_campaign = articleId:

```json
{
  "Fb-comment": "utm_source=facebook&utm_medium=comment",
  "YouTube-comment": "utm_source=YouTube&utm_medium=comment"
}
```

**Q: Как изменить Bearer токен API?**

A:
1. Сгенерировать новый токен: `openssl rand -base64 32`
2. Изменить в `/opt/redirect/.env`: `API_TOKEN=новый_токен`
3. Перезапустить: `systemctl restart redirect.service`
4. Обновить токен в n8n workflows

---

**Последнее обновление:** 2026-01-11
