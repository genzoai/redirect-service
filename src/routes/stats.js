const express = require('express');
const router = express.Router();
const { mainPool } = require('../config/database');
const { authenticate } = require('../middleware/auth');

/**
 * API endpoint для статистики
 * GET /api/stats?site=realtruetales&period=week
 */
router.get('/', authenticate, async (req, res) => {
  const { site, period, start_date, end_date, limit, countries_limit, source } = req.query;

  if (!site) {
    return res.status(400).json({
      success: false,
      error: 'Parameter "site" is required'
    });
  }

  // Определяем лимит постов
  let articlesLimit = 5; // По умолчанию топ 5
  if (limit === 'all') {
    articlesLimit = null; // Без лимита - все посты
  } else if (limit && !isNaN(parseInt(limit))) {
    articlesLimit = parseInt(limit);
  }

  // Определяем лимит стран
  let countriesLimit = 5; // По умолчанию топ 5 стран
  if (countries_limit === '0') {
    countriesLimit = 0; // Не показывать статистику по странам
  } else if (countries_limit === 'all') {
    countriesLimit = null; // Без лимита - все страны
  } else if (countries_limit && !isNaN(parseInt(countries_limit))) {
    countriesLimit = parseInt(countries_limit);
  }

  try {
    // Определяем временной диапазон
    const dateRange = getDateRange(period, start_date, end_date);

    if (!dateRange) {
      return res.status(400).json({
        success: false,
        error: 'Invalid period or date range'
      });
    }

    const sourceFilter = source ? String(source) : null;
    const sourceCondition = sourceFilter ? ' AND source = ?' : '';
    const baseParams = [site, dateRange.start, dateRange.end];
    const paramsWithSource = sourceFilter ? [...baseParams, sourceFilter] : baseParams;

    // Получаем общее количество переходов (clicks)
    const [totalClicks] = await mainPool.query(
      `SELECT COUNT(*) as total
       FROM clicks
       WHERE site = ?
         AND type = 'click'
         AND created_at >= ?
         AND created_at <= ?${sourceCondition}`,
      paramsWithSource
    );

    // Получаем общее количество preview (боты)
    const [totalPreviews] = await mainPool.query(
      `SELECT COUNT(*) as total
       FROM clicks
       WHERE site = ?
         AND type = 'preview'
         AND created_at >= ?
         AND created_at <= ?${sourceCondition}`,
      paramsWithSource
    );

    // Получаем статьи по кликам
    const clicksQuery = `SELECT
         article_id,
         COUNT(*) as clicks
       FROM clicks
       WHERE site = ?
         AND type = 'click'
         AND created_at >= ?
         AND created_at <= ?
         ${sourceFilter ? 'AND source = ?' : ''}
       GROUP BY article_id
       ORDER BY clicks DESC
       ${articlesLimit ? `LIMIT ${articlesLimit}` : ''}`;

    const [topArticles] = await mainPool.query(clicksQuery, paramsWithSource);

    // Получаем статьи по preview (боты)
    const previewsQuery = `SELECT
         article_id,
         COUNT(*) as previews
       FROM clicks
       WHERE site = ?
         AND type = 'preview'
         AND created_at >= ?
         AND created_at <= ?
         ${sourceFilter ? 'AND source = ?' : ''}
       GROUP BY article_id
       ORDER BY previews DESC
       ${articlesLimit ? `LIMIT ${articlesLimit}` : ''}`;

    const [topPreviewArticles] = await mainPool.query(previewsQuery, paramsWithSource);

    // Получаем статистику по странам (если нужно)
    let topCountries = [];
    let articleCountries = {};

    if (countriesLimit !== 0) {
      // Топ стран для всего сайта
      const countriesQuery = `SELECT
          country,
          COUNT(*) as clicks
        FROM clicks
        WHERE site = ?
          AND type = 'click'
          AND created_at >= ?
          AND created_at <= ?
          AND country IS NOT NULL
          ${sourceFilter ? 'AND source = ?' : ''}
        GROUP BY country
        ORDER BY clicks DESC
        ${countriesLimit ? `LIMIT ${countriesLimit}` : ''}`;

      const [countriesData] = await mainPool.query(countriesQuery, paramsWithSource);

      // Вычисляем процент для каждой страны
      const totalClicksCount = totalClicks[0].total;
      topCountries = countriesData.map(row => ({
        country: row.country,
        clicks: row.clicks,
        percentage: totalClicksCount > 0 ? parseFloat((row.clicks / totalClicksCount * 100).toFixed(2)) : 0
      }));

      // Топ стран для каждой статьи (если есть статьи)
      if (topArticles.length > 0) {
        const articleIds = topArticles.map(a => a.article_id);
        const placeholders = articleIds.map(() => '?').join(',');

        const articleCountriesQuery = `SELECT
            article_id,
            country,
            COUNT(*) as clicks
          FROM clicks
          WHERE site = ?
            AND type = 'click'
            AND created_at >= ?
            AND created_at <= ?
            AND country IS NOT NULL
            ${sourceFilter ? 'AND source = ?' : ''}
            AND article_id IN (${placeholders})
          GROUP BY article_id, country
          ORDER BY article_id, clicks DESC`;

        const [articleCountriesData] = await mainPool.query(
          articleCountriesQuery,
          sourceFilter
            ? [site, dateRange.start, dateRange.end, sourceFilter, ...articleIds]
            : [site, dateRange.start, dateRange.end, ...articleIds]
        );

        // Группируем по article_id и берем топ N стран для каждой статьи
        articleCountriesData.forEach(row => {
          if (!articleCountries[row.article_id]) {
            articleCountries[row.article_id] = [];
          }

          // Добавляем только если еще не достигли лимита для этой статьи
          if (countriesLimit === null || articleCountries[row.article_id].length < countriesLimit) {
            articleCountries[row.article_id].push({
              country: row.country,
              clicks: row.clicks
            });
          }
        });
      }
    }

    // Формируем ссылки на статьи
    const sites = require('../../config/sites.json');
    const siteConfig = sites[site];

    if (!siteConfig) {
      return res.status(404).json({
        success: false,
        error: 'Site not found'
      });
    }

    const topArticlesWithUrls = topArticles.map(article => {
      const articleData = {
        article_id: article.article_id,
        clicks: article.clicks,
        url: buildArticleUrl(siteConfig, article.article_id)
      };

      // Добавляем топ стран для статьи, если включена статистика по странам
      if (countriesLimit !== 0 && articleCountries[article.article_id]) {
        articleData.top_countries = articleCountries[article.article_id];
      }

      return articleData;
    });

    const topPreviewArticlesWithUrls = topPreviewArticles.map(article => ({
      article_id: article.article_id,
      previews: article.previews,
      url: buildArticleUrl(siteConfig, article.article_id)
    }));

    // Формируем ответ
    const responseData = {
      site,
      period: period || 'custom',
      source: sourceFilter || undefined,
      date_range: {
        start: dateRange.start,
        end: dateRange.end
      },
      total_clicks: totalClicks[0].total,
      total_previews: totalPreviews[0].total,
      articles_count: topArticles.length,
      top_articles: topArticlesWithUrls,
      top_articles_previews: topPreviewArticlesWithUrls
    };

    // Добавляем статистику по странам только если включена
    if (countriesLimit !== 0) {
      responseData.top_countries = topCountries;
    }

    // Добавляем разбивку по источникам (всегда по всем источникам)
    const sourcesQuery = `SELECT
        source,
        SUM(CASE WHEN type = 'click' THEN 1 ELSE 0 END) AS clicks,
        SUM(CASE WHEN type = 'preview' THEN 1 ELSE 0 END) AS previews,
        COUNT(*) AS total
      FROM clicks
      WHERE site = ?
        AND created_at >= ?
        AND created_at <= ?
      GROUP BY source
      ORDER BY total DESC`;

    const [sourcesData] = await mainPool.query(sourcesQuery, baseParams);
    responseData.sources = sourcesData.map(row => ({
      source: row.source,
      clicks: row.clicks,
      previews: row.previews,
      total: row.total
    }));

    // Возвращаем результат
    return res.json({
      success: true,
      data: responseData
    });

  } catch (error) {
    console.error('Error fetching stats:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * Определяет временной диапазон на основе периода
 */
function getDateRange(period, startDate, endDate) {
  const now = new Date();
  let start, end;

  if (period) {
    // Обработка различных типов периодов

    // Скользящие периоды (относительно текущего момента)
    if (period === 'day') {
      start = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      end = now;
    }
    else if (period === 'week') {
      start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      end = now;
    }
    else if (period === 'month') {
      start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      end = now;
    }
    else if (period === 'quarter') {
      start = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
      end = now;
    }
    // Вчерашний день (полные сутки)
    else if (period === 'yesterday') {
      const yesterday = new Date(now);
      yesterday.setDate(yesterday.getDate() - 1);
      start = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 0, 0, 0);
      end = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 23, 59, 59);
    }
    // Последняя полная неделя (понедельник-воскресенье)
    else if (period.startsWith('last_week')) {
      const match = period.match(/^last_week_(\d+)$/);
      const weeksBack = match ? parseInt(match[1]) + 1 : 1;

      const lastMonday = new Date(now);
      lastMonday.setDate(lastMonday.getDate() - lastMonday.getDay() + (lastMonday.getDay() === 0 ? -6 : 1));
      lastMonday.setDate(lastMonday.getDate() - (7 * weeksBack));

      start = new Date(lastMonday.getFullYear(), lastMonday.getMonth(), lastMonday.getDate(), 0, 0, 0);
      end = new Date(start);
      end.setDate(end.getDate() + 6);
      end.setHours(23, 59, 59);
    }
    // Последний полный месяц
    else if (period.startsWith('last_month')) {
      const match = period.match(/^last_month_(\d+)$/);
      const monthsBack = match ? parseInt(match[1]) + 1 : 1;

      const lastMonth = new Date(now.getFullYear(), now.getMonth() - monthsBack, 1);
      start = new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 1, 0, 0, 0);
      end = new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 0, 23, 59, 59);
    }
    // Конкретный месяц: month_1_2026
    else if (period.startsWith('month_')) {
      const match = period.match(/^month_(\d+)_(\d+)$/);
      if (!match) return null;

      const month = parseInt(match[1]) - 1; // 0-11
      const year = parseInt(match[2]);

      if (month < 0 || month > 11) return null;

      start = new Date(year, month, 1, 0, 0, 0);
      end = new Date(year, month + 1, 0, 23, 59, 59);
    }
    // Конкретный квартал: quarter_1_2026
    else if (period.startsWith('quarter_')) {
      const match = period.match(/^quarter_(\d+)_(\d+)$/);
      if (!match) return null;

      const quarter = parseInt(match[1]); // 1-4
      const year = parseInt(match[2]);

      if (quarter < 1 || quarter > 4) return null;

      const startMonth = (quarter - 1) * 3;
      start = new Date(year, startMonth, 1, 0, 0, 0);
      end = new Date(year, startMonth + 3, 0, 23, 59, 59);
    }
    // Последние 365 дней
    else if (period === 'year_to_date') {
      start = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
      end = now;
    }
    // Вся история (от первого клика)
    else if (period === 'all_time') {
      start = new Date('2000-01-01 00:00:00'); // Начало времён
      end = now;
    }
    // Конкретный год: year_2026
    else if (period.startsWith('year_')) {
      const match = period.match(/^year_(\d+)$/);
      if (!match) return null;

      const year = parseInt(match[1]);
      start = new Date(year, 0, 1, 0, 0, 0);
      end = new Date(year, 11, 31, 23, 59, 59);
    }
    else {
      return null;
    }
  }
  // Кастомный период
  else if (startDate && endDate) {
    start = new Date(startDate);
    end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return null;
    }
  }
  else {
    return null;
  }

  return {
    start: formatDateTime(start),
    end: formatDateTime(end)
  };
}

/**
 * Форматирует дату в MySQL datetime формат
 */
function formatDateTime(date) {
  return date.toISOString().slice(0, 19).replace('T', ' ');
}

module.exports = router;

/**
 * Строит URL статьи с учетом url_pattern
 */
function buildArticleUrl(siteConfig, articleId) {
  const urlPattern = siteConfig.url_pattern || '/{articleId}/';
  let urlPath = urlPattern.replace('{articleId}', articleId);

  if (!urlPath.startsWith('/')) {
    urlPath = `/${urlPath}`;
  }

  return `https://${siteConfig.domain}${urlPath}`;
}
