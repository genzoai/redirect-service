/**
 * Universal OG Data Fetcher - Strategy Router
 *
 * Выбирает стратегию получения OG данных на основе siteConfig.og_method:
 * - wordpress_db: Прямой SQL запрос к WordPress БД
 * - html_fetch: HTTP запрос + парсинг OG тегов
 * - api: Кастомный API endpoint (будущее)
 */

const { fetchOGFromWordPress } = require('./og-fetcher-wordpress');
const { fetchOGFromHTML } = require('./og-fetcher-html');

/**
 * Универсальная функция для получения OG данных
 * @param {Object} siteConfig - Конфигурация сайта из sites.json
 * @param {string} articleId - ID/slug статьи
 * @returns {Promise<Object|null>} OG данные или null
 */
async function fetchOGData(siteConfig, articleId) {
  const method = siteConfig.og_method || 'wordpress_db'; // Обратная совместимость

  try {
    switch(method) {
      case 'wordpress_db':
        return await fetchOGFromWordPress(siteConfig, articleId);

      case 'html_fetch':
        return await fetchOGFromHTML(siteConfig, articleId);

      case 'api':
        // TODO: Реализовать в будущем
        throw new Error('API method not implemented yet');

      default:
        console.error(`Unknown og_method: ${method} for site ${siteConfig.domain}`);
        return null;
    }
  } catch (error) {
    console.error(`Error fetching OG data for ${siteConfig.domain}/${articleId}:`, error.message);
    return null;
  }
}

module.exports = { fetchOGData };
