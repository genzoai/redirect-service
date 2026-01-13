const mysql = require('mysql2/promise');

// Пул для основной БД (логирование кликов)
const mainPool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Пул для чтения WordPress БД (опциональный - только если используется og_method: wordpress_db)
let wpPool = null;

if (process.env.WP_DB_HOST && process.env.WP_DB_USER && process.env.WP_DB_PASSWORD) {
  wpPool = mysql.createPool({
    host: process.env.WP_DB_HOST,
    user: process.env.WP_DB_USER,
    password: process.env.WP_DB_PASSWORD,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  });
  console.log('✅ WordPress DB pool created');
} else {
  console.log('ℹ️  WordPress DB pool not created (WP_DB_* variables not set)');
  console.log('   Sites with og_method: "html_fetch" will work without WordPress DB');
}

module.exports = {
  mainPool,
  wpPool
};
