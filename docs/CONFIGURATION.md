# Configuration Guide

Полное руководство по настройке Universal Redirect Service.

---

## 📁 Файлы конфигурации

### Основные файлы

| Файл | Расположение | Описание |
|------|--------------|----------|
| `.env` | Корень проекта | Переменные окружения |
| `sites.json` | `config/sites.json` | Конфигурация сайтов |
| `utm-sources.json` | `config/utm-sources.json` | Источники трафика |

---

## 🔐 Переменные окружения (.env)

### Создание файла

```bash
cp config/.env.example .env
nano .env
```

### Обязательные параметры

```bash
# Сервис
PORT=3077
NODE_ENV=production

# База данных (логирование кликов)
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=redirect_user
DB_PASSWORD=your_secure_password_here
DB_NAME=redirect_db

# API
API_TOKEN=your_secure_api_token_here
```

### Опциональные параметры

```bash
# WordPress БД (только если используется og_method: wordpress_db)
WP_DB_HOST=127.0.0.1
WP_DB_PORT=3306
WP_DB_USER=wp_readonly
WP_DB_PASSWORD=your_wp_password_here

# Функции
ENABLE_GEOIP=true                    # Включить GeoIP tracking
GEOIP_AUTO_UPDATE=true               # Автообновление базы GeoIP
```

### Генерация безопасных паролей/токенов

```bash
# Пароль для БД
openssl rand -base64 24

# API токен
openssl rand -base64 32
```

---

## 🌐 Конфигурация сайтов (sites.json)

### Структура файла

```json
{
  "site_id": {
    "domain": "example.com",
    "og_method": "wordpress_db" | "html_fetch",
    "url_pattern": "/{articleId}/",   // опционально
    "wp_db": "database_name",         // опционально
    "description": "Human description" // опционально
  }
}
```

### Обязательные поля

| Поле | Тип | Описание |
|------|-----|----------|
| `domain` | string | Домен сайта (без https://) |
| `og_method` | string | Метод получения OG данных |

### Опциональные поля

| Поле | Тип | Используется в | Описание |
|------|-----|----------------|----------|
| `url_pattern` | string | Все | Шаблон URL для редиректа и получения OG данных. Поддерживает `{articleId}`. По умолчанию: `/{articleId}/` |
| `wp_db` | string | `wordpress_db` | Название WordPress БД |
| `db` | string | Legacy | Старый формат (обратная совместимость) |
| `description` | string | Все | Описание сайта для документации |

---

## 📋 OG Methods (Методы получения OG данных)

### 1. wordpress_db - WordPress Database

**Использование:** Когда есть прямой доступ к MySQL БД WordPress сайта.

**Конфигурация:**
```json
{
  "myblog": {
    "domain": "myblog.com",
    "og_method": "wordpress_db",
    "wp_db": "wp_myblog",
    "description": "My WordPress blog"
  }
}
```

**Требования:**
- Прямой доступ к MySQL БД
- Read-only пользователь (рекомендуется)
- Настроенные WP_DB_* переменные в .env

**Как это работает:**
1. SQL запрос к таблице `wp_posts`
2. Получение `post_title`, `post_excerpt`, `post_content`
3. Получение featured image из `wp_postmeta`
4. Поддержка Yoast SEO / RankMath мета-данных

**Преимущества:**
- ✅ Очень быстро (~10-20ms)
- ✅ Доступ к SEO мета-данным
- ✅ Нет HTTP запросов

**Недостатки:**
- ❌ Требуется доступ к БД
- ❌ Только для WordPress сайтов

---

### 2. html_fetch - HTML Parsing

**Использование:** Для любых сайтов без доступа к БД.

**Конфигурация:**
```json
{
  "mysite": {
    "domain": "example.com",
    "og_method": "html_fetch",
    "description": "Static site / Any CMS"
  }
}
```

**Требования:**
- Сайт должен быть доступен по HTTPS
- Сайт должен возвращать OG теги или meta теги

**Как это работает:**
1. HTTP GET запрос к `https://domain.com/article-slug/`
2. Парсинг HTML с помощью cheerio
3. Извлечение OG тегов:
   - `<meta property="og:title">`
   - `<meta property="og:description">`
   - `<meta property="og:image">`
4. Fallback на обычные meta теги и `<title>`

**Преимущества:**
- ✅ Работает с любым CMS (WordPress, Drupal, custom, static)
- ✅ Не требует доступа к БД
- ✅ Универсально

**Недостатки:**
- ❌ Медленнее (~50-200ms)
- ❌ HTTP запрос на каждый preview
- ❌ Зависит от доступности сайта

**Настройки HTTP запроса:**
- Timeout: 5 секунд
- Max redirects: 3
- User-Agent: `Mozilla/5.0 (compatible; RedirectBot/1.0)`

---

## 📝 Примеры конфигураций

### Пример 1: Только WordPress сайты

```json
{
  "blog1": {
    "domain": "myblog.com",
    "og_method": "wordpress_db",
    "wp_db": "wp_myblog",
    "description": "Main blog"
  },
  "blog2": {
    "domain": "secondblog.com",
    "og_method": "wordpress_db",
    "wp_db": "wp_secondblog",
    "description": "Secondary blog"
  }
}
```

**.env требует:**
```bash
WP_DB_HOST=127.0.0.1
WP_DB_USER=wp_readonly
WP_DB_PASSWORD=password
```

---

### Пример 2: Смешанная конфигурация

```json
{
  "wpblog": {
    "domain": "myblog.com",
    "og_method": "wordpress_db",
    "wp_db": "wp_myblog",
    "description": "WordPress blog with DB access"
  },
  "landingpage": {
    "domain": "landing.com",
    "og_method": "html_fetch",
    "description": "Static landing page"
  },
  "shopify": {
    "domain": "shop.com",
    "og_method": "html_fetch",
    "description": "Shopify store"
  }
}
```

**.env может не иметь WP_DB_*** - сайты с `html_fetch` будут работать.

---

### Пример 3: Кастомные URL схемы (url_pattern)

**Стандартная схема** (по умолчанию):
```json
{
  "blog": {
    "domain": "example.com",
    "og_method": "wordpress_db",
    "wp_db": "example_db",
    "url_pattern": "/{articleId}/"
  }
}
```
→ Результат: `https://example.com/article-slug/?utm_params`

**Блог с префиксом:**
```json
{
  "blog": {
    "domain": "example.com",
    "og_method": "html_fetch",
    "url_pattern": "/blog/{articleId}/"
  }
}
```
→ Результат: `https://example.com/blog/article-slug/?utm_params`

**Вложенная структура:**
```json
{
  "news": {
    "domain": "media.com",
    "og_method": "html_fetch",
    "url_pattern": "/news/articles/{articleId}/"
  }
}
```
→ Результат: `https://media.com/news/articles/article-slug/?utm_params`

**Без слеша в конце:**
```json
{
  "docs": {
    "domain": "docs.example.com",
    "og_method": "html_fetch",
    "url_pattern": "/{articleId}"
  }
}
```
→ Результат: `https://docs.example.com/article-slug?utm_params`

**Примечание:** `{articleId}` - обязательный плейсхолдер, который заменяется на slug статьи. Этот же шаблон используется в API (`/api/stats`) для генерации ссылок статей.

---

### Пример 4: Обратная совместимость (Legacy)

**Старый формат** (всё ещё поддерживается):
```json
{
  "oldsite": {
    "domain": "old.com",
    "db": "old_db"
  }
}
```

Автоматически интерпретируется как:
```json
{
  "oldsite": {
    "domain": "old.com",
    "og_method": "wordpress_db",  // default
    "wp_db": "old_db"              // поле db → wp_db
  }
}
```

---

## 🚦 Источники трафика (utm-sources.json)

### Структура

```json
{
  "source_id": "utm_source=value&utm_medium=value"
}
```

Или объектный формат:
```json
{
  "source_id": {
    "utm_source": "value",
    "utm_medium": "value"
  }
}
```

### Пример

```json
{
  "fb": "utm_source=facebook&utm_medium=social",
  "yt": "utm_source=youtube&utm_medium=video",
  "ig": "utm_source=instagram&utm_medium=social",
  "tg": "utm_source=telegram&utm_medium=messenger",
  "email": "utm_source=newsletter&utm_medium=email",
  "tiktok": "utm_source=tiktok&utm_medium=social"
}
```

### Как используется

URL редиректа:
```
https://go.domain.com/go/fb/myblog/article-slug
```

Финальный редирект:
```
https://myblog.com/article-slug/?utm_source=facebook&utm_medium=social&utm_campaign=article-slug
```

**Примечание:** `utm_campaign` автоматически добавляется = `article_slug`

Для отдельных кампаний внутри одного source используй формат:
```
https://go.domain.com/go/fb/spring_sale/myblog/article-slug
```

Финальный редирект:
```
https://myblog.com/article-slug/?utm_source=facebook&utm_medium=social&utm_campaign=spring_sale&utm_content=article-slug
```

---

## ✅ Проверка конфигурации

### 1. Проверка синтаксиса JSON

```bash
# Проверить sites.json
cat config/sites.json | jq '.'

# Проверить utm-sources.json
cat config/utm-sources.json | jq '.'
```

### 2. Проверка подключения к БД

```bash
# Основная БД
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SELECT 1;"

# WordPress БД (если используется)
mysql -h $WP_DB_HOST -u $WP_DB_USER -p$WP_DB_PASSWORD -e "SHOW DATABASES;"
```

### 3. Тестирование OG fetch

**WordPress DB:**
```bash
# Проверить таблицу
mysql -h $WP_DB_HOST -u $WP_DB_USER -p$WP_DB_PASSWORD wp_myblog \
  -e "SELECT post_name, post_title FROM wp_posts WHERE post_status='publish' LIMIT 5;"
```

**HTML Fetch:**
```bash
# Проверить доступность сайта и OG теги
curl -s https://example.com/article/ | grep -i 'og:title'
```

### 4. Проверка работы сервиса

```bash
# Health check
curl http://localhost:3077/health

# Тестовый редирект (как человек)
curl -i "http://localhost:3077/go/fb/mysite/test-article"

# Тестовый preview (как бот)
curl -A "facebookexternalhit/1.1" "http://localhost:3077/go/fb/mysite/test-article"
```

---

## 🔄 Изменение конфигурации

### Добавление нового сайта

1. Отредактировать `config/sites.json`:
```bash
nano config/sites.json
```

2. Добавить новый сайт:
```json
{
  "newsite": {
    "domain": "newsite.com",
    "og_method": "html_fetch",
    "description": "New site"
  }
}
```

3. Перезапустить сервис:
```bash
systemctl restart redirect.service
```

**Примечание:** Не требуется миграция БД или изменение кода!

---

## 🚨 Типичные ошибки

### Ошибка: "WordPress DB pool not initialized"

**Причина:** WP_DB_* переменные не заданы, но сайт использует `og_method: wordpress_db`

**Решение:**
1. Добавить в `.env`:
```bash
WP_DB_HOST=127.0.0.1
WP_DB_USER=wp_readonly
WP_DB_PASSWORD=password
```

2. ИЛИ изменить на `html_fetch`:
```json
{
  "mysite": {
    "og_method": "html_fetch"
  }
}
```

---

### Ошибка: "Unknown site"

**Причина:** ID сайта в URL не найден в `sites.json`

**Пример ошибочного URL:**
```
https://go.domain.com/go/fb/wrongsite/article
                               ^^^^^^^^^ нет в sites.json
```

**Решение:** Добавить сайт в `config/sites.json`

---

### Ошибка: "Unknown source"

**Причина:** Источник трафика не найден в `utm-sources.json`

**Решение:** Добавить источник в `config/utm-sources.json`

---

## 📚 Дополнительные ресурсы

- [API Documentation](API.md) - REST API для статистики
- [GeoIP Setup](GEOIP.md) - Настройка GeoIP
- [Installation Guide](INSTALLATION.md) - Установка сервиса

---

**© 2026 Genzo AI LLP**
