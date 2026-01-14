const express = require('express');
const router = express.Router();
const geoip = require('geoip-lite');
const { mainPool } = require('../config/database');
const { detectBot } = require('../middleware/bot-detector');
const { fetchOGData } = require('../utils/og-fetcher');
const utmSources = require('../../config/utm-sources.json');
const sites = require('../../config/sites.json');

/**
 * Обработка редиректа: /go/:source/:site/:articleId
 */
router.get('/:source/:site/:articleId', async (req, res) => {
  const { source, site, articleId } = req.params;
  const userAgent = req.headers['user-agent'] || '';
  const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
  const isBot = detectBot(userAgent);

  // Определяем страну по IP
  let country = null;
  const geo = geoip.lookup(ip);
  if (geo && geo.country) {
    country = geo.country; // ISO код страны (US, UA, PL и т.д.)
  }

  // Проверяем, существует ли source в utm-sources.json
  if (!utmSources[source]) {
    return res.status(404).send('Unknown source');
  }

  // Проверяем, существует ли сайт в sites.json
  if (!sites[site]) {
    return res.status(404).send('Unknown site');
  }

  const siteConfig = sites[site];
  const utmParams = utmSources[source];

  // Формируем URL по шаблону (если задан) или используем дефолтную схему
  const urlPattern = siteConfig.url_pattern || '/{articleId}/';
  const urlPath = urlPattern.replace('{articleId}', articleId);
  const targetUrl = `https://${siteConfig.domain}${urlPath}?${utmParams}&utm_campaign=${articleId}`;

  try {
    // Если это бот - показываем OG preview
    if (isBot) {
      // Логируем как preview
      await logClick(ip, userAgent, source, site, articleId, 'preview', country);

      // Получаем OG данные (универсальный fetcher выберет стратегию)
      const ogData = await fetchOGData(siteConfig, articleId);

      if (!ogData) {
        // Если статья не найдена, делаем редирект на главную
        return res.redirect(302, `https://${siteConfig.domain}`);
      }

      // Отдаём HTML с OG тегами
      const html = generateOGHTML(ogData, targetUrl, siteConfig.domain);
      return res.send(html);
    }

    // Если это человек - логируем и редиректим
    await logClick(ip, userAgent, source, site, articleId, 'click', country);
    return res.redirect(302, targetUrl);

  } catch (error) {
    console.error('Error processing redirect:', error);
    return res.status(500).send('Internal server error');
  }
});

/**
 * Логирует клик в базу данных
 */
async function logClick(ip, userAgent, source, site, articleId, type, country) {
  try {
    await mainPool.query(
      `INSERT INTO clicks (ip, country, user_agent, source, site, article_id, type, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
      [ip, country, userAgent, source, site, articleId, type]
    );
  } catch (error) {
    console.error('Error logging click:', error);
  }
}

/**
 * Генерирует HTML с OG тегами для ботов
 */
function generateOGHTML(ogData, url, siteName) {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta property="og:type" content="article">
  <meta property="og:url" content="${url}">
  <meta property="og:title" content="${escapeHtml(ogData.title)}">
  <meta property="og:description" content="${escapeHtml(ogData.description)}">
  ${ogData.image ? `<meta property="og:image" content="${ogData.image}">` : ''}
  <meta property="og:site_name" content="${siteName}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(ogData.title)}">
  <meta name="twitter:description" content="${escapeHtml(ogData.description)}">
  ${ogData.image ? `<meta name="twitter:image" content="${ogData.image}">` : ''}
  <title>${escapeHtml(ogData.title)}</title>
</head>
<body>
</body>
</html>`;
}

/**
 * Экранирует HTML для безопасного вывода
 */
function escapeHtml(text) {
  if (!text) return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = router;
