-- Миграция: добавление поля country в таблицу clicks
-- Дата: 2026-01-12

USE redirect_db;

-- Добавляем поле country (ISO 3166-1 alpha-2 код страны)
ALTER TABLE clicks
ADD COLUMN country VARCHAR(2) NULL COMMENT 'ISO код страны (US, UA, PL и т.д.)'
AFTER ip;

-- Добавляем индекс для быстрого поиска по стране
ALTER TABLE clicks
ADD INDEX idx_country (country);

-- Добавляем составной индекс для статистики по сайтам и странам
ALTER TABLE clicks
ADD INDEX idx_site_country (site, country);
