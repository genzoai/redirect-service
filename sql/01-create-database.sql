-- Создание базы данных для redirect сервиса
CREATE DATABASE IF NOT EXISTS redirect_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Создание пользователя для redirect приложения
CREATE USER IF NOT EXISTS 'redirect_user'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Выдача прав на базу redirect_db
GRANT ALL PRIVILEGES ON redirect_db.* TO 'redirect_user'@'localhost';

FLUSH PRIVILEGES;
