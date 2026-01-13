/**
 * Middleware для проверки Bearer токена
 */
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Missing or invalid Authorization header'
    });
  }

  const token = authHeader.substring(7); // Убираем "Bearer "

  if (token !== process.env.API_TOKEN) {
    return res.status(403).json({
      success: false,
      error: 'Invalid token'
    });
  }

  next();
}

module.exports = { authenticate };
