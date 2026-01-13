/**
 * Определяет, является ли запрос от бота или человека
 */
function detectBot(userAgent) {
  if (!userAgent) return false;

  const botPatterns = [
    'facebookexternalhit',
    'Facebot',
    'Twitterbot',
    'TelegramBot',
    'Slackbot',
    'WhatsApp',
    'LinkedInBot',
    'Discordbot',
    'bot',
    'crawler',
    'spider',
    'scraper'
  ];

  return botPatterns.some(pattern =>
    userAgent.toLowerCase().includes(pattern.toLowerCase())
  );
}

module.exports = { detectBot };
