const { wpPool } = require('../config/database');

/**
 * Получает OG данные статьи из WordPress БД
 * @param {Object} siteConfig - Конфигурация сайта
 * @param {string} articleSlug - Slug статьи
 * @returns {Promise<Object|null>} OG данные
 */
async function fetchOGFromWordPress(siteConfig, articleSlug) {
  // Проверка доступности wpPool
  if (!wpPool) {
    console.error('WordPress DB pool not initialized. Set WP_DB_* environment variables.');
    return null;
  }

  // Обратная совместимость: поддержка старого поля "db"
  const dbName = siteConfig.wp_db || siteConfig.db;

  if (!dbName) {
    console.error('WordPress database name not specified in siteConfig');
    return null;
  }

  try {
    const connection = await wpPool.getConnection();

    // Запрос для получения данных статьи
    const [posts] = await connection.query(
      `SELECT
        p.ID,
        p.post_title,
        p.post_excerpt,
        p.post_content
      FROM ${dbName}.wp_posts p
      WHERE p.post_name = ?
        AND p.post_status = 'publish'
        AND p.post_type = 'post'
      LIMIT 1`,
      [articleSlug]
    );

    if (posts.length === 0) {
      connection.release();
      return null;
    }

    const post = posts[0];

    // Получаем featured image
    const [thumbnails] = await connection.query(
      `SELECT meta_value
      FROM ${dbName}.wp_postmeta
      WHERE post_id = ?
        AND meta_key = '_thumbnail_id'
      LIMIT 1`,
      [post.ID]
    );

    let imageUrl = null;
    if (thumbnails.length > 0) {
      const thumbnailId = thumbnails[0].meta_value;
      const [attachments] = await connection.query(
        `SELECT guid
        FROM ${dbName}.wp_posts
        WHERE ID = ?
        LIMIT 1`,
        [thumbnailId]
      );
      if (attachments.length > 0) {
        imageUrl = attachments[0].guid;
      }
    }

    // Получаем Yoast/RankMath мета-данные (если есть)
    const [metaData] = await connection.query(
      `SELECT meta_key, meta_value
      FROM ${dbName}.wp_postmeta
      WHERE post_id = ?
        AND meta_key IN ('_yoast_wpseo_title', '_yoast_wpseo_metadesc', 'rank_math_title', 'rank_math_description')`,
      [post.ID]
    );

    connection.release();

    // Формируем OG данные
    let title = post.post_title;
    let description = post.post_excerpt || truncateToLastWord(stripHtml(post.post_content), 160);

    // Используем SEO данные, если есть
    metaData.forEach(meta => {
      if (meta.meta_key === '_yoast_wpseo_title' || meta.meta_key === 'rank_math_title') {
        title = meta.meta_value || title;
      }
      if (meta.meta_key === '_yoast_wpseo_metadesc' || meta.meta_key === 'rank_math_description') {
        description = meta.meta_value || description;
      }
    });

    return {
      title: cleanQuotes(title),
      description: cleanQuotes(description),
      image: imageUrl
    };

  } catch (error) {
    console.error('Error fetching OG data:', error);
    return null;
  }
}

/**
 * Убирает HTML теги из текста
 */
function stripHtml(html) {
  return html.replace(/<[^>]*>/g, '').trim();
}

/**
 * Обрезает текст до максимальной длины, не разрывая слова
 */
function truncateToLastWord(text, maxLength) {
  if (text.length <= maxLength) {
    return text;
  }

  // Обрезаем до maxLength
  let truncated = text.substring(0, maxLength);

  // Находим последний пробел
  const lastSpaceIndex = truncated.lastIndexOf(' ');

  // Если нашли пробел, обрезаем до него
  if (lastSpaceIndex > 0) {
    truncated = truncated.substring(0, lastSpaceIndex);
  }

  return truncated;
}

/**
 * Заменяет типографские кавычки на обычные одинарные
 */
function cleanQuotes(text) {
  if (!text) return '';
  return text
    .replace(/"/g, "'")                  // Обычные двойные → одинарные
    .replace(/\u201C/g, "'")             // Типографская левая " (U+201C) → одинарная
    .replace(/\u201D/g, "'")             // Типографская правая " (U+201D) → одинарная
    .replace(/\u2019/g, "'")             // Типографский апостроф ' (U+2019) → обычный
    .replace(/\u2018/g, "'");            // Типографская левая ' (U+2018) → обычная
}

module.exports = { fetchOGFromWordPress };
