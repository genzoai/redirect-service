# Universal Redirect Service

**Универсальный сервис для UTM редиректов с OG preview, GeoIP tracking и полным API для n8n интеграции**

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![Node](https://img.shields.io/badge/node-%3E%3D24.0.0-brightgreen.svg)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](docker/)

---

## 🎯 Возможности

### Основные функции
- ✅ **Универсальный OG Fetching** - поддержка разных источников данных
- ✅ **UTM Tracking** - автоматическое добавление UTM меток
- ✅ **GeoIP** - определение страны по IP с автообновлением базы
- ✅ **Bot Detection** - распознавание ботов соцсетей для OG preview
- ✅ **n8n API** - полный REST API для интеграции с n8n
- ✅ **Docker Ready** - готовые контейнеры для деплоя
- ✅ **Auto-Install** - интерактивный установщик

### Стратегии получения OG данных

#### 1. WordPress Database (прямой доступ к БД)
```json
{
  "mysite": {
    "domain": "example.com",
    "og_method": "wordpress_db",
    "wp_db": "wp_database"
  }
}
```
- Прямой SQL запрос к WordPress БД
- Поддержка Yoast SEO и RankMath
- Получение featured image
- **Быстро:** ~10-20ms

#### 2. HTML Fetch (парсинг любого сайта)
```json
{
  "mysite": {
    "domain": "example.com",
    "og_method": "html_fetch"
  }
}
```
- HTTP запрос + cheerio парсинг
- Работает с любым сайтом (не только WordPress)
- Не требует доступа к БД
- **Универсально:** подходит для любого CMS

---

## 🚀 Быстрый старт

### Вариант 1: Автоматическая установка (рекомендуется)

```bash
# Клонировать репозиторий
git clone https://github.com/genzoai/redirect-service.git
cd redirect-service

# Запустить интерактивный установщик
sudo bash scripts/install.sh
```

Установщик настроит:
- ✅ Проверку системных требований
- ✅ Конфигурацию сайтов и источников трафика
- ✅ URL шаблоны для сайтов (`url_pattern`)
- ✅ База данных MySQL/MariaDB
- ✅ SSL сертификат (Let's Encrypt)
- ✅ Nginx reverse proxy
- ✅ Systemd сервис с автозапуском

### Вариант 2: Docker

```bash
# Создать .env и config/sites.json
cp config/.env.example .env
cp config/sites.example.json config/sites.json

# Отредактировать конфиги
nano .env
nano config/sites.json

# Запустить (используйте уникальный project name)
docker compose -p redirect-goexample -f docker/docker-compose.yml up -d
```

### Вариант 3: Ручная установка

```bash
# Установить зависимости
npm install --production

# Настроить конфиги
cp config/.env.example .env
cp config/sites.example.json config/sites.json

# Отредактировать .env и sites.json
nano .env
nano config/sites.json

# Настроить БД
mysql -u root -p < sql/01-create-database.sql
mysql -u root -p < sql/02-create-tables.sql
mysql -u root -p < sql/04-add-country-field.sql

# Запустить
npm start
```

---

## 📋 Системные требования

### Обязательные
- **Node.js** >= 24.0.0
- **npm** >= 11.0.0
- **MySQL/MariaDB** >= 8.4.0

### Опциональные
- **nginx** >= 1.18 (для reverse proxy)
- **certbot** (для SSL)
- **Docker** (для контейнеризации)

### Для WordPress DB метода
- **Прямой доступ** к MySQL БД WordPress сайта
- **Read-only пользователь** БД (безопасность)

### Примечания
- **Node.js ниже 24.0.0 не поддерживается** - обновитесь до Node.js **24.13.0 LTS**
- Для Ubuntu/Debian установка: `curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && apt-get install -y nodejs`

---

## ⚙️ Конфигурация

### Основные файлы

| Файл | Описание |
|------|----------|
| `.env` | Переменные окружения (порт, БД, токены) |
| `config/sites.json` | Конфигурация сайтов и OG методов |
| `config/utm-sources.json` | Источники трафика и UTM метки |

**Примечание:** поддерживаются `DB_PORT` и `WP_DB_PORT` для нестандартных портов MySQL.

### Пример sites.json

```json
{
  "mywordpress": {
    "domain": "myblog.com",
    "og_method": "wordpress_db",
    "wp_db": "wp_myblog",
    "description": "WordPress site"
  },
  "mysite": {
    "domain": "example.com",
    "og_method": "html_fetch",
    "description": "Any website"
  }
}
```

**Подробнее:** [docs/CONFIGURATION.md](docs/CONFIGURATION.md) (шаблон `url_pattern` используется для редиректа, OG fetching и ссылок в API)

---

## 🌐 Использование

### Базовый URL редиректа

```
https://go.yourdomain.com/go/{source}/{site}/{articleId}
```

**Параметры:**
- `{source}` - источник трафика (fb, ig, tg, email и т.д.)
- `{campaign}` - опциональная кампания внутри источника (например, `spring_sale`)
- `{site}` - ID сайта из sites.json
- `{articleId}` - slug/ID статьи

### Примеры

#### Facebook → WordPress сайт
```
https://go.yourdomain.com/go/fb/mywordpress/my-article-slug
```
Редирект → `https://myblog.com/my-article-slug/?utm_source=facebook&utm_medium=social&utm_campaign=my-article-slug`

#### Facebook campaign → WordPress сайт
```
https://go.yourdomain.com/go/fb/spring_sale/mywordpress/my-article-slug
```
Редирект → `https://myblog.com/my-article-slug/?utm_source=facebook&utm_medium=social&utm_campaign=spring_sale&utm_content=my-article-slug`

#### Instagram → любой сайт
```
https://go.yourdomain.com/go/ig/mysite/some-page
```
Редирект → `https://example.com/some-page/?utm_source=instagram&utm_medium=social&utm_campaign=some-page`

### Для ботов соцсетей

Боты (Facebook, Telegram, Instagram crawler) получают HTML с OG тегами:
```html
<meta property="og:title" content="Article Title">
<meta property="og:description" content="Description">
<meta property="og:image" content="https://...">
```

---

## 📊 API Статистики (n8n)

### Endpoint

```
GET /api/stats
```

**Авторизация:** Bearer Token
**Источник токена:** переменная `API_TOKEN` в `.env`

### Параметры

| Параметр | Описание | Обязательный |
|----------|----------|--------------|
| `site` | ID сайта | ✅ Да |
| `period` | Период (day, week, month, all_time) | ✅ Да |
| `limit` | Количество постов (5, 10, all) | Нет (default: 5) |
| `countries_limit` | Количество стран (5, 10, all, 0) | Нет (default: 5) |
| `source` | Фильтр по источнику (fb, yt, tg, ...) | Нет |
| `campaign` | Фильтр по кампании внутри источника | Нет |

### Примеры запросов

```bash
# Статистика за неделю, топ-5 постов, топ-5 стран
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://go.yourdomain.com/api/stats?site=mysite&period=week"

# Все посты за месяц, топ-10 стран
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://go.yourdomain.com/api/stats?site=mysite&period=month&limit=all&countries_limit=10"

# Без статистики по странам
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://go.yourdomain.com/api/stats?site=mysite&period=day&countries_limit=0"
```

**Подробнее:** [docs/API.md](docs/API.md)

---

## 🗺️ GeoIP Tracking

### Автоматическое определение страны

Каждый клик автоматически определяет страну пользователя по IP:
- ISO код страны (US, UA, PL, ES и т.д.)
- Автообновление базы GeoIP (1 раз в месяц)
- Статистика по странам в API

### База данных

- **Источник:** MaxMind GeoLite2
- **Обновление:** Автоматически 1-го числа каждого месяца
- **Точность:** ~99% для стран

**Подробнее:** [docs/GEOIP.md](docs/GEOIP.md)

---

## 🔄 Обновление сервиса

```bash
# Автоматическое обновление с GitHub
sudo bash scripts/update.sh
```

Скрипт:
1. Проверяет новую версию
2. Создает backup
3. Загружает обновление
4. Применяет миграции БД
5. Перезапускает сервис
6. При ошибке - автоматический rollback

---

## 📖 Документация

- **[API Documentation](docs/API.md)** - REST API для n8n
- **[Configuration Guide](docs/CONFIGURATION.md)** - Настройка sites.json
- **[GeoIP Setup](docs/GEOIP.md)** - Настройка GeoIP
- **[Installation Guide](docs/INSTALLATION.md)** - Детальная установка
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Варианты деплоя
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Решение проблем

---

## 🏗️ Архитектура

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ https://go.domain.com/go/fb/site/article
       ↓
┌──────────────────┐
│  Redirect Service│
│  (Node.js/Express│
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ↓         ↓
┌────────┐  ┌──────────────┐
│  Bot?  │  │  GeoIP       │
└────┬───┘  │  (Country)   │
     │      └──────────────┘
     │
  Yes│No
     │
┌────┴─────┬──────────┐
│          │          │
↓          ↓          ↓
OG HTML   Redirect   Log to DB
(preview) (302)      (MySQL)
```

### OG Fetching Strategies

```
┌─────────────────────┐
│  fetchOGData()      │
│  (Router)           │
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
    ↓             ↓
┌──────────┐  ┌──────────┐
│WordPress │  │   HTML   │
│    DB    │  │  Fetch   │
│ (SQL)    │  │(cheerio) │
└──────────┘  └──────────┘
```

---

## 🛠️ Разработка

```bash
# Установить все зависимости (включая dev)
npm install

# Запустить в dev режиме (nodemon)
npm run dev

# Запустить wizard настройки
npm run install-wizard
```

---

## 📊 База данных

### Таблица: clicks

| Поле | Тип | Описание |
|------|-----|----------|
| id | BIGINT | Автоинкремент ID |
| ip | VARCHAR(45) | IP адрес |
| country | VARCHAR(2) | ISO код страны |
| user_agent | TEXT | User-Agent |
| source | VARCHAR(50) | fb, ig, tg, email |
| site | VARCHAR(100) | ID сайта |
| article_id | VARCHAR(255) | Slug статьи |
| type | ENUM | click / preview |
| created_at | DATETIME | Время клика |

---

## 🤝 Поддержка

- **Email:** support@genzo.ai
- **Лицензирование:** legal@genzo.ai
- **Issues:** [GitHub Issues](https://github.com/genzoai/redirect-service/issues)

---

## 📄 Лицензия

**Proprietary License** © 2026 Genzo AI LLP

Это проприетарное программное обеспечение. Использование разрешено только для собственных нужд.
Распространение, перепродажа или предоставление услуг третьим лицам **запрещены** без письменного разрешения Genzo AI LLP.

Подробнее: [LICENSE](LICENSE)

---

## 🙏 Благодарности

- [MaxMind](https://www.maxmind.com/) - GeoLite2 база данных
- [cheerio](https://cheerio.js.org/) - HTML парсинг
- [axios](https://axios-http.com/) - HTTP клиент

---

**Создано с ❤️ командой [Genzo AI LLP](https://genzo.ai)**
