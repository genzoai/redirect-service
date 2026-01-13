#!/usr/bin/env node

/**
 * Скрипт для заполнения поля country у существующих записей
 * Использует geoip-lite для определения страны по IP
 */

require('dotenv').config();
const geoip = require('geoip-lite');
const { mainPool } = require('../config/database');

async function backfillCountries() {
  console.log('=== Backfill Countries Script Started ===');
  console.log(`Started at: ${new Date().toISOString()}\n`);

  try {
    // 1. Получаем количество записей без country
    const [countResult] = await mainPool.query(
      'SELECT COUNT(*) as total FROM clicks WHERE country IS NULL'
    );
    const totalRecords = countResult[0].total;

    console.log(`📊 Total records without country: ${totalRecords}`);

    if (totalRecords === 0) {
      console.log('✅ All records already have country data!');
      await mainPool.end();
      return;
    }

    // 2. Получаем все записи без country (порциями по 1000)
    const batchSize = 1000;
    let offset = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;

    while (offset < totalRecords) {
      console.log(`\n📦 Processing batch ${offset + 1} - ${Math.min(offset + batchSize, totalRecords)} of ${totalRecords}...`);

      const [records] = await mainPool.query(
        `SELECT id, ip FROM clicks WHERE country IS NULL LIMIT ? OFFSET ?`,
        [batchSize, offset]
      );

      // 3. Для каждой записи определяем страну и обновляем
      let batchUpdated = 0;
      let batchSkipped = 0;

      for (const record of records) {
        const geo = geoip.lookup(record.ip);

        if (geo && geo.country) {
          // Обновляем запись
          await mainPool.query(
            'UPDATE clicks SET country = ? WHERE id = ?',
            [geo.country, record.id]
          );
          batchUpdated++;
        } else {
          // IP не определился (локальный, невалидный и т.д.)
          batchSkipped++;
        }
      }

      totalUpdated += batchUpdated;
      totalSkipped += batchSkipped;

      console.log(`   ✅ Updated: ${batchUpdated}`);
      console.log(`   ⏭️  Skipped: ${batchSkipped}`);

      offset += batchSize;
    }

    // 4. Финальная статистика
    console.log('\n=== Final Statistics ===');
    console.log(`✅ Total updated: ${totalUpdated}`);
    console.log(`⏭️  Total skipped: ${totalSkipped} (local/invalid IPs)`);

    // Проверяем результат
    const [remainingResult] = await mainPool.query(
      'SELECT COUNT(*) as total FROM clicks WHERE country IS NULL'
    );
    console.log(`📊 Records still without country: ${remainingResult[0].total}`);

    // Показываем топ стран после обновления
    const [topCountries] = await mainPool.query(
      `SELECT country, COUNT(*) as count
       FROM clicks
       WHERE country IS NOT NULL
       GROUP BY country
       ORDER BY count DESC
       LIMIT 10`
    );

    console.log('\n📍 Top 10 countries after backfill:');
    topCountries.forEach((row, index) => {
      console.log(`   ${index + 1}. ${row.country}: ${row.count} clicks`);
    });

  } catch (error) {
    console.error('\n❌ Error during backfill:', error);
    throw error;
  } finally {
    await mainPool.end();
    console.log('\n=== Script Completed ===');
    console.log(`Finished at: ${new Date().toISOString()}`);
  }
}

// Запускаем скрипт
backfillCountries()
  .then(() => {
    console.log('\n✅ Backfill completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Backfill failed:', error);
    process.exit(1);
  });
