-- Используем базу redirect_db
USE redirect_db;

-- Таблица для логирования кликов
CREATE TABLE IF NOT EXISTS clicks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ip VARCHAR(45) NOT NULL COMMENT 'IP адрес посетителя',
  user_agent TEXT NOT NULL COMMENT 'User-Agent браузера',
  source VARCHAR(50) NOT NULL COMMENT 'Источник (fb, tg, ig, email)',
  site VARCHAR(100) NOT NULL COMMENT 'Название сайта',
  article_id VARCHAR(255) NOT NULL COMMENT 'ID/slug статьи',
  type ENUM('click', 'preview') NOT NULL DEFAULT 'click' COMMENT 'Тип: клик человека или preview бота',
  created_at DATETIME NOT NULL COMMENT 'Время клика',
  INDEX idx_site (site),
  INDEX idx_source (source),
  INDEX idx_article (article_id),
  INDEX idx_type (type),
  INDEX idx_created_at (created_at),
  INDEX idx_site_created (site, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
