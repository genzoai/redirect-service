/**
 * OG Data Fetcher - HTML Parsing Strategy
 *
 * Получает OG данные путем парсинга HTML страницы.
 * Используется для сайтов, к которым нет прямого доступа к БД.
 */

const cheerio = require('cheerio');
const axios = require('axios');

/**
 * Получает OG данные путем HTTP запроса и парсинга HTML
 * @param {Object} siteConfig - Конфигурация сайта
 * @param {string} articleSlug - Slug статьи
 * @returns {Promise<Object|null>} OG данные
 */
async function fetchOGFromHTML(siteConfig, articleSlug) {
  const url = `https://${siteConfig.domain}/${articleSlug}/`;

  try {
    // HTTP запрос к странице
    const { data } = await axios.get(url, {
      timeout: 5000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; RedirectBot/1.0; +https://genzo.ai/bot)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive'
      },
      maxRedirects: 3,
      validateStatus: (status) => status >= 200 && status < 400
    });

    // Парсинг HTML
    const $ = cheerio.load(data);

    // Извлекаем OG теги
    const ogTitle = $('meta[property="og:title"]').attr('content');
    const ogDescription = $('meta[property="og:description"]').attr('content');
    const ogImage = $('meta[property="og:image"]').attr('content');

    // Fallback на обычные meta теги и HTML элементы
    const title = ogTitle ||
                  $('meta[name="title"]').attr('content') ||
                  $('title').text().trim() ||
                  null;

    const description = ogDescription ||
                       $('meta[name="description"]').attr('content') ||
                       $('meta[property="description"]').attr('content') ||
                       null;

    const image = ogImage ||
                 $('meta[name="image"]').attr('content') ||
                 $('meta[property="image"]').attr('content') ||
                 $('link[rel="image_src"]').attr('href') ||
                 null;

    // Проверяем, что хотя бы title найден
    if (!title) {
      console.warn(`No title found for ${url}`);
      return null;
    }

    return {
      title: cleanText(title),
      description: cleanText(description),
      image: image ? normalizeImageUrl(image, siteConfig.domain) : null
    };

  } catch (error) {
    if (error.response) {
      console.error(`HTTP ${error.response.status} for ${url}:`, error.message);
    } else if (error.code === 'ECONNABORTED') {
      console.error(`Timeout fetching ${url}`);
    } else {
      console.error(`Failed to fetch OG from ${url}:`, error.message);
    }
    return null;
  }
}

/**
 * Очищает текст от лишних пробелов и HTML entities
 */
function cleanText(text) {
  if (!text) return null;

  return text
    .replace(/\s+/g, ' ')           // Множественные пробелы → один
    .replace(/&nbsp;/g, ' ')         // &nbsp; → пробел
    .replace(/&quot;/g, '"')         // &quot; → "
    .replace(/&apos;/g, "'")         // &apos; → '
    .replace(/&amp;/g, '&')          // &amp; → &
    .replace(/&lt;/g, '<')           // &lt; → <
    .replace(/&gt;/g, '>')           // &gt; → >
    .trim();
}

/**
 * Нормализует URL изображения (делает абсолютным если относительный)
 */
function normalizeImageUrl(imageUrl, domain) {
  if (!imageUrl) return null;

  // Уже абсолютный URL
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl;
  }

  // Протокол-относительный URL (//example.com/image.jpg)
  if (imageUrl.startsWith('//')) {
    return `https:${imageUrl}`;
  }

  // Относительный URL от корня (/images/photo.jpg)
  if (imageUrl.startsWith('/')) {
    return `https://${domain}${imageUrl}`;
  }

  // Относительный URL (images/photo.jpg)
  return `https://${domain}/${imageUrl}`;
}

module.exports = { fetchOGFromHTML };
