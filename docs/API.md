# API Статистики

> **📌 Полная совместимость с n8n workflows!**
> Этот API endpoint сохраняет 100% совместимость с существующими интеграциями n8n.

---

## О сервисе

Universal Redirect Service поддерживает разные методы получения OG данных:
- **WordPress Database** - прямой SQL запрос к БД
- **HTML Fetch** - парсинг OG тегов с любого сайта

Независимо от метода, **API статистики работает одинаково** для всех сайтов.

**Подробнее о конфигурации:** [CONFIGURATION.md](CONFIGURATION.md)

---

## Endpoint

  Method: GET

  URL: https://go.yourdomain.com/api/stats

  Authentication:
  - Type: Generic Credential Type → Header Auth
  - Name: Authorization
  - Value: Bearer your_secure_api_token_here

  Query Parameters:
  site: realtruetales          (обязательно)
  period: week                 (обязательно: day, week, month, quarter, all_time и так далее)
  limit: 5                     (опционально: количество постов, по умолчанию 5, all = все посты)
  countries_limit: 5           (опционально: количество стран, по умолчанию 5, all = все страны, 0 = не показывать)
  source: fb                   (опционально: фильтр по источнику, например fb/yt/tg)
  campaign: spring_sale        (опционально: фильтр по кампании внутри источника)

  Или для кастомного периода:
  site: realtruetales
  start_date: 2026-01-01
  end_date: 2026-01-10

## Redirect URL Format

Сервис поддерживает два формата redirect URL:

### Legacy

```text
https://go.yourdomain.com/go/{source}/{site}/{articleId}
```

Пример:

```text
https://go.yourdomain.com/go/fb/realtruetales/t95buwa
```

Результат:
- логируется `source = fb`
- `utm_campaign = articleId`

### Новый формат с campaign

```text
https://go.yourdomain.com/go/{source}/{campaign}/{site}/{articleId}
```

Пример:

```text
https://go.yourdomain.com/go/fb/spring_sale/realtruetales/t95buwa
```

Результат:
- логируется `source = fb`
- логируется `campaign = spring_sale`
- `utm_campaign = spring_sale`
- `utm_content = articleId`

## Типы периодов

### Скользящие периоды (от момента запроса)

| Period         | Описание           | Пример                      |
|----------------|--------------------|-----------------------------|
| `day`          | Последние 24 часа  | 10 янв 12:00 → 11 янв 12:00 |
| `week`         | Последние 7 дней   | 4 янв → 11 янв              |
| `month`        | Последние 30 дней  | 12 дек → 11 янв             |
| `quarter`      | Последние 90 дней  | 13 окт → 11 янв             |
| `year_to_date` | Последние 365 дней | 11 янв 2025 → 11 янв 2026   |
| `all_time`     | Вся история        | с первого клика → сейчас    |

### Календарные периоды

| Period         | Описание 			   | Пример 			 |
|----------------|---------------------------------|-----------------------------|
| `yesterday`    | Вчерашний день (полные сутки)   | 10 янв 00:00 → 10 янв 23:59 |
| `last_week`    | Последняя полная неделя (пн-вс) | 30 дек → 5 янв              |
| `last_week_1`  | 1 неделя назад от последней     | 23 дек → 29 дек 		 |
| `last_week_2`  | 2 недели назад от последней     | 16 дек → 22 дек 		 |
| `last_month`   | Последний полный месяц          | 1 дек → 31 дек 		 |
| `last_month_1` | 1 месяц назад от последнего     | 1 ноя → 30 ноя 		 |
| `last_month_2` | 2 месяца назад от последнего    | 1 окт → 31 окт 		 |

### Конкретные периоды

| Period 	   | Описание	       | Пример		     |
|------------------|-------------------|---------------------|
| `month_1_2026`   | Январь 2026       | 1 янв → 31 янв 2026 |
| `month_12_2025`  | Декабрь 2025      | 1 дек → 31 дек 2025 |
| `quarter_1_2026` | Q1 2026 (янв-мар) | 1 янв → 31 мар 2026 |
| `quarter_4_2025` | Q4 2025 (окт-дек) | 1 окт → 31 дек 2025 |
| `year_2026`      | Весь 2026 год     | 1 янв → 31 дек 2026 |

### Кастомный период

```
start_date=2026-01-01&end_date=2026-01-10
```

---

## Параметр limit (количество постов)

По умолчанию API возвращает **топ 5 постов**. Можно изменить:

| Значение 	     | Описание 	   |
|--------------------|---------------------|
| `5` (по умолчанию) | Топ 5 постов 	   |
| `10`               | Топ 10 постов 	   |
| `20` 		     | Топ 20 постов	   |
| `all`		     | ВСЕ посты за период |

**Примеры:**
- `limit=10` - топ 10 постов
- `limit=all` - все посты без ограничений

---

## Параметр countries_limit (статистика по странам)

По умолчанию API возвращает **топ 5 стран** для сайта и для каждой статьи. Можно изменить:

| Значение 	         | Описание 	                          |
|------------------------|----------------------------------------|
| `5` (по умолчанию)     | Топ 5 стран                            |
| `10`                   | Топ 10 стран                           |
| `20` 		         | Топ 20 стран	                          |
| `all`		         | ВСЕ страны                             |
| `0`		         | НЕ показывать статистику по странам    |

**Примеры:**
- `countries_limit=10` - топ 10 стран
- `countries_limit=all` - все страны без ограничений
- `countries_limit=0` - не добавлять поля `top_countries` в ответ

**Что включает статистика по странам:**
- `top_countries` - топ стран для всего сайта (с процентами)
- `top_countries` внутри каждой статьи - топ стран для этой статьи

---

## Примеры запросов

### 1. Вчерашний день
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=yesterday"
```

### 2. Последняя полная неделя
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=last_week"
```

### 3. Январь 2026
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=month_1_2026"
```

### 4. Первый квартал 2026
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=quarter_1_2026"
```

### 5. Кастомный период
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&start_date=2026-01-01&end_date=2026-01-10"
```

### 6. Вся история (all_time)
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=all_time"
```

### 7. ВСЕ посты за период (limit=all)
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=last_month&limit=all"
```

### 8. Топ 20 постов за всё время
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=all_time&limit=20"
```

### 9. Статистика с топ-10 стран
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week&countries_limit=10"
```

### 10. Статистика по конкретному источнику
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week&source=fb"
```

### 11. Статистика по конкретной кампании
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week&source=fb&campaign=spring_sale"
```

### 12. Статистика со ВСЕМИ странами
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=month&countries_limit=all"
```

### 13. Статистика БЕЗ данных по странам
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://go.genzo.ai/api/stats?site=realtruetales&period=week&countries_limit=0"
```

---

## Формат ответа

```json
{
  "success": true,
  "data": {
    "site": "realtruetales",
    "period": "yesterday",
    "source": "fb",
    "campaign": "spring_sale",
    "date_range": {
      "start": "2026-01-10 00:00:00",
      "end": "2026-01-10 23:59:59"
    },
    "total_clicks": 42,
    "total_previews": 15,
    "articles_count": 5,
    "top_countries": [
      {
        "country": "ES",
        "clicks": 18,
        "percentage": 42.86
      },
      {
        "country": "UA",
        "clicks": 12,
        "percentage": 28.57
      },
      {
        "country": "PL",
        "clicks": 8,
        "percentage": 19.05
      },
      {
        "country": "DE",
        "clicks": 4,
        "percentage": 9.52
      }
    ],
    "top_articles": [
      {
        "article_id": "t95buwa",
        "clicks": 25,
        "url": "https://realtruetales.com/t95buwa/",
        "top_countries": [
          {
            "country": "ES",
            "clicks": 12
          },
          {
            "country": "UA",
            "clicks": 8
          },
          {
            "country": "PL",
            "clicks": 5
          }
        ]
      },
      {
        "article_id": "abc123",
        "clicks": 10,
        "url": "https://realtruetales.com/abc123/",
        "top_countries": [
          {
            "country": "DE",
            "clicks": 6
          },
          {
            "country": "ES",
            "clicks": 4
          }
        ]
      }
    ],
    "top_articles_previews": [
      {
        "article_id": "t95buwa",
        "previews": 8,
        "url": "https://realtruetales.com/t95buwa/"
      }
    ],
    "sources": [
      {
        "source": "fb",
        "clicks": 25,
        "previews": 10,
        "total": 35
      }
    ],
    "campaigns": [
      {
        "campaign": "spring_sale",
        "source": "fb",
        "clicks": 25,
        "previews": 10,
        "total": 35
      }
    ]
  }
}
```

### Описание полей ответа

- `total_clicks` - количество переходов людей (тип `click`)
- `total_previews` - количество preview ботов Facebook/Telegram (тип `preview`)
- `articles_count` - количество статей в ответе
- `source` - фильтр по источнику, если был передан в запросе
- `campaign` - фильтр по кампании, если был передан в запросе
- `top_countries` - **НОВОЕ:** топ стран для всего сайта (если `countries_limit` != 0)
  - `country` - ISO код страны (ES, UA, PL и т.д.)
  - `clicks` - количество кликов из этой страны
  - `percentage` - процент от общего числа кликов
- `top_articles` - топ статей по переходам людей
  - `top_countries` - **НОВОЕ:** топ стран для этой статьи (если `countries_limit` != 0)
- `top_articles_previews` - топ статей по preview ботов
- `sources` - разбивка по источникам трафика (click + preview)
- `campaigns` - разбивка по кампаниям (click + preview)

**Примечание:** Поля `top_countries` появляются только если параметр `countries_limit` не равен `0` (по умолчанию топ-5).

---

## Настройка в n8n

**HTTP Request нода:**

1. **Method:** `GET`
2. **URL:** `https://go.genzo.ai/api/stats`
3. **Authentication:**
   - Type: `Header Auth`
   - Name: `Authorization`
   - Value: `Bearer your_secure_api_token_here`
4. **Query Parameters:**
   - `site`: `{{ $json.site }}` или `realtruetales`
   - `period`: `yesterday` или другой период
   - `source`: `fb` (опционально)
   - `campaign`: `spring_sale` (опционально)

**Пример динамических параметров:**
```
site: {{ $json.site }}
period: last_week
source: fb
campaign: spring_sale
```

---

## Коды ошибок

| Код | Ошибка         | Причина 					 |
|-----|----------------|-------------------------------------------------|
| 401 | Unauthorized   | Нет или неверный токен 			 |
| 400 | Bad Request    | Не указан параметр `site` или неверный `period` |
| 404 | Not Found      | Сайт не найден в конфигурации 			 |
| 500 | Internal Error | Ошибка сервера/БД 				 |

---

**Дата обновления:** 2026-03-18
**Версия API:** 1.1
