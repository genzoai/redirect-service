# Redirect Service - UTM Tracking & OG Preview

Сервис для редиректа с UTM метками и OG preview для социальных сетей.

## Как работает

### Схема работы

```
Запрос: https://go.genzo.ai/go/{source}/{site}/{articleId}
          ↓
Определение: бот или человек?
          ↓
    ┌─────┴─────┐
    │           │
   БОТ       ЧЕЛОВЕК
    │           │
    ↓           ↓
OG HTML    302 Redirect
с тегами   + UTM метки
    │           │
    └─────┬─────┘
          ↓
  Логирование клика
```

### Пример запроса

**URL:** `https://go.genzo.ai/go/fb/realtruetales/t95buwa`

**Если человек:**
- Редирект → `https://realtruetales.com/t95buwa/?utm_source=facebook&utm_medium=comment&utm_campaign=auto`
- Логируется как `type = click`

**Если бот (Facebook):**
- Возвращает HTML с OG тегами (title, description, image)
- Логируется как `type = preview`
- Бот видит превью статьи

## Структура проекта

```
/opt/redirect/
├── redirect-server.js      # Главный файл приложения
├── package.json             # Зависимости
├── .env                     # Конфигурация (пароли, токены)
│
├── config/
│   ├── database.js          # Подключение к MySQL
│   ├── sites.json           # Список сайтов
│   ├── utm-sources.json     # Словарь UTM меток
│   ├── redirect.service     # systemd сервис (копия)
│   └── nginx-go.genzo.ai.conf (копия)
│
├── middleware/
│   ├── auth.js              # Проверка Bearer токена
│   └── bot-detector.js      # Определение ботов
│
├── routes/
│   ├── redirect.js          # Логика редиректов
│   └── stats.js             # API статистики
│
├── utils/
│   └── og-fetcher.js        # Получение OG из WordPress
│
└── sql/
    ├── 01-create-database.sql
    ├── 02-create-tables.sql
    └── 03-create-readonly-user.sql
```

## Конфигурация

### Переменные окружения (.env)

Файл: `/opt/redirect/.env`

```bash
# Сервер
PORT=3077
NODE_ENV=production

# База данных (логирование кликов)
DB_HOST=127.0.0.1
DB_USER=redirect_user
DB_PASSWORD=your_secure_password_here
DB_NAME=redirect_db

# WordPress базы (read-only)
WP_DB_HOST=127.0.0.1
WP_DB_USER=wp_readonly
WP_DB_PASSWORD=your_secure_password_here

# API токен
API_TOKEN=your_secure_api_token_here
```

### Nginx конфигурация

Файл: `/etc/nginx/sites-available/go.genzo.ai`

Проксирует запросы с `https://go.genzo.ai` на `localhost:3077`

### Systemd сервис

Файл: `/etc/systemd/system/redirect.service`

## База данных

### Основная БД (redirect_db)

**Пользователь:** `redirect_user@localhost`

**Таблица:** `clicks`

```sql
- id (BIGINT)
- ip (VARCHAR) - IP адрес
- user_agent (TEXT) - User-Agent
- source (VARCHAR) - fb, tg, ig, email
- site (VARCHAR) - realtruetales, rozpovediserdza, nathnenne, radoscz
- article_id (VARCHAR) - slug статьи
- type (ENUM) - click или preview
- created_at (DATETIME)
```

### WordPress БД (read-only)

**Пользователь:** `wp_readonly@localhost`

**Доступ:** SELECT на 4 базы:
- `realtruetales_db`
- `rozpovediserdza_db`
- `wp_nathnenne`
- `radoscz_db`

### Подключение к БД

```bash
# Основная БД
mysql -u redirect_user -p redirect_db

# WordPress БД (read-only)
mysql -u wp_readonly -p realtruetales_db
```

## Управление сервисом

```bash
# Запуск
systemctl start redirect.service

# Остановка
systemctl stop redirect.service

# Перезапуск
systemctl restart redirect.service

# Статус
systemctl status redirect.service

# Логи
journalctl -u redirect.service -f
```

## API Статистики

**Endpoint:** `GET /api/stats`

**Авторизация:** Bearer Token

**Параметры:**
- `site` (обязательно) - название сайта
- `period` (опционально) - day, week, month, quarter
- `start_date` & `end_date` (опционально) - кастомный период

**Пример запроса:**

```bash
curl -H "Authorization: Bearer your_secure_api_token_here" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week"
```

**Ответ:**

```json
{
  "success": true,
  "data": {
    "site": "realtruetales",
    "period": "week",
    "date_range": {
      "start": "2026-01-03 21:50:01",
      "end": "2026-01-10 21:50:01"
    },
    "total_clicks": 42,
    "top_articles": [
      {
        "article_id": "t95buwa",
        "clicks": 15,
        "url": "https://realtruetales.com/t95buwa/"
      }
    ]
  }
}
```

## Troubleshooting

### Проверка работы сервиса

```bash
# Health check
curl https://go.genzo.ai/health

# Проверка редиректа
curl -i "https://go.genzo.ai/go/fb/realtruetales/ARTICLE_SLUG"

# Проверка OG preview (как бот)
curl -A "facebookexternalhit/1.1" "https://go.genzo.ai/go/fb/realtruetales/ARTICLE_SLUG"
```

### Просмотр логов

```bash
# Логи приложения
journalctl -u redirect.service -n 100

# Логи nginx
tail -f /var/log/nginx/go.genzo.ai-access.log
tail -f /var/log/nginx/go.genzo.ai-error.log
```

### Проверка базы данных

```bash
# Количество кликов
mysql -e "SELECT COUNT(*) FROM redirect_db.clicks;"

# Последние клики
mysql -e "SELECT * FROM redirect_db.clicks ORDER BY created_at DESC LIMIT 10;" redirect_db

# Статистика по типам
mysql -e "SELECT type, COUNT(*) FROM redirect_db.clicks GROUP BY type;" redirect_db
```

## Технические детали

- **Язык:** Node.js 24.13.0 LTS
- **Framework:** Express.js
- **База данных:** MariaDB (MySQL)
- **Порт:** 3077
- **SSL:** Let's Encrypt (автообновление через certbot)
- **Процесс:** systemd сервис с автозапуском

## Файлы конфигурации

| Файл | Расположение |
|------|--------------|
| .env | /opt/redirect/.env |
| nginx | /etc/nginx/sites-available/go.genzo.ai |
| systemd | /etc/systemd/system/redirect.service |
| sites.json | /opt/redirect/config/sites.json |
| utm-sources.json | /opt/redirect/config/utm-sources.json |

---

**Автор:** Claude Code
**Дата создания:** 2026-01-10
**Версия:** 1.0
