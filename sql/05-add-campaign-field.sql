-- Миграция: добавление поля campaign в таблицу clicks
-- Дата: 2026-03-18

USE redirect_db;

-- Добавляем поле campaign для различения кампаний внутри одного source
ALTER TABLE clicks
ADD COLUMN campaign VARCHAR(100) NULL COMMENT 'Маркетинговая кампания (например, spring_sale)'
AFTER source;

-- Индекс для выборок по campaign
ALTER TABLE clicks
ADD INDEX idx_campaign (campaign);

-- Составной индекс для статистики по сайту, campaign и времени
ALTER TABLE clicks
ADD INDEX idx_site_campaign_created (site, campaign, created_at);
