-- Создание read-only пользователя для доступа к WordPress базам данных
CREATE USER IF NOT EXISTS 'wp_readonly'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Выдача прав SELECT на все WordPress базы данных
GRANT SELECT ON realtruetales_db.* TO 'wp_readonly'@'localhost';
GRANT SELECT ON rozpovediserdza_db.* TO 'wp_readonly'@'localhost';
GRANT SELECT ON wp_nathnenne.* TO 'wp_readonly'@'localhost';
GRANT SELECT ON radoscz_db.* TO 'wp_readonly'@'localhost';

FLUSH PRIVILEGES;
