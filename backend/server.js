const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  next();
});

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  client_encoding: 'UTF8',
});

pool.connect((err, client, release) => {
  if (err) {
    console.error('❌ Ошибка подключения к БД:', err.stack);
  } else {
    console.log('✅ Подключение к PostgreSQL успешно');
    release();
  }
});

// ===== ФУНКЦИЯ ПРОВЕРКИ МАТА =====

async function checkText(text) {
  const words = await pool.query('SELECT word FROM banned_words');
  const bannedList = words.rows.map(r => r.word.toLowerCase());
  const lowerText = text.toLowerCase();

  for (const word of bannedList) {
    if (lowerText.includes(word)) {
      return { clean: false, word };
    }
  }
  return { clean: true };
}

// ===== API =====

app.get('/', (req, res) => {
  res.json({ message: 'Сервер "Скрытые Таланты" работает!' });
});

// ===== РЕГИСТРАЦИЯ (с паролем + 100 монет) =====

app.post('/api/users', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Заполните имя, email и пароль',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        error: 'Пароль должен быть минимум 6 символов',
      });
    }

    const existing = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [email]
    );
    if (existing.rows.length > 0) {
      return res.status(400).json({
        success: false,
        error: 'Этот email уже зарегистрирован',
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      'INSERT INTO users (name, email, password_hash, coins_balance) VALUES ($1, $2, $3, $4) RETURNING id, name, email, coins_balance, is_premium, created_at',
      [name, email, passwordHash, 100]
    );

    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== ВХОД =====

app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Введите email и пароль',
      });
    }

    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Неверный email или пароль',
      });
    }

    const user = result.rows[0];

    if (!user.password_hash) {
      return res.status(401).json({
        success: false,
        error: 'У этого аккаунта нет пароля. Зарегистрируйтесь заново.',
      });
    }

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(401).json({
        success: false,
        error: 'Неверный email или пароль',
      });
    }

    res.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        coins_balance: user.coins_balance,
        is_premium: user.is_premium,
        created_at: user.created_at,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, coins_balance, is_premium, created_at FROM users ORDER BY created_at DESC');
    res.json({ success: true, users: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== ПОЛЬЗОВАТЕЛЬ ПО ID =====

app.get('/api/users/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, email, coins_balance, is_premium, created_at FROM users WHERE id = $1',
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Пользователь не найден' });
    }
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== ДОНАТЫ =====

app.post('/api/donate', async (req, res) => {
  try {
    const { sender_user_id, recipient_user_id, amount, short_id } = req.body;

    if (!sender_user_id || !recipient_user_id || !amount) {
      return res.status(400).json({
        success: false,
        error: 'Заполните все поля: sender_user_id, recipient_user_id, amount',
      });
    }

    if (amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Сумма доната должна быть больше 0',
      });
    }

    if (sender_user_id === recipient_user_id) {
      return res.status(400).json({
        success: false,
        error: 'Нельзя донатить самому себе',
      });
    }

    const recipient = await pool.query(
      'SELECT id, name FROM users WHERE id = $1',
      [recipient_user_id]
    );
    if (recipient.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Получатель не найден',
      });
    }

    const sender = await pool.query(
      'SELECT coins_balance FROM users WHERE id = $1',
      [sender_user_id]
    );
    if (sender.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Отправитель не найден',
      });
    }

    const senderBalance = sender.rows[0].coins_balance;
    if (senderBalance < amount) {
      return res.status(400).json({
        success: false,
        error: `Недостаточно монет. У вас ${senderBalance}, нужно ${amount}`,
      });
    }

    await pool.query(
      'UPDATE users SET coins_balance = coins_balance - $1 WHERE id = $2',
      [amount, sender_user_id]
    );

    await pool.query(
      'UPDATE users SET coins_balance = coins_balance + $1 WHERE id = $2',
      [amount, recipient_user_id]
    );

    const result = await pool.query(
      'INSERT INTO donations (sender_user_id, recipient_user_id, amount, short_id) VALUES ($1, $2, $3, $4) RETURNING *',
      [sender_user_id, recipient_user_id, amount, short_id || null]
    );

    res.json({
      success: true,
      donation: result.rows[0],
      recipient_name: recipient.rows[0].name,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== ИСТОРИЯ ДОНАТОВ =====

app.get('/api/donations/received/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT donations.*, users.name as sender_name 
       FROM donations 
       JOIN users ON donations.sender_user_id = users.id 
       WHERE donations.recipient_user_id = $1 
       ORDER BY donations.created_at DESC 
       LIMIT 50`,
      [req.params.user_id]
    );
    res.json({ success: true, donations: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/donations/sent/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT donations.*, users.name as recipient_name 
       FROM donations 
       JOIN users ON donations.recipient_user_id = users.id 
       WHERE donations.sender_user_id = $1 
       ORDER BY donations.created_at DESC 
       LIMIT 50`,
      [req.params.user_id]
    );
    res.json({ success: true, donations: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== МОДЕРАЦИЯ =====

app.post('/api/moderate/check', async (req, res) => {
  try {
    const { text } = req.body;
    const result = await checkText(text);
    res.json({ success: true, clean: result.clean, bannedWord: result.word || null });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== СООБЩЕНИЯ =====

app.post('/api/messages', async (req, res) => {
  try {
    const { room_id, user_id, text } = req.body;

    const check = await checkText(text);
    if (!check.clean) {
      return res.status(400).json({
        success: false,
        error: 'Сообщение содержит запрещённые слова',
        blocked: true,
      });
    }

    const result = await pool.query(
      'INSERT INTO messages (room_id, user_id, text) VALUES ($1, $2, $3) RETURNING *',
      [room_id, user_id, text]
    );
    res.json({ success: true, message: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/messages/:room_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT messages.*, users.name as user_name 
       FROM messages 
       JOIN users ON messages.user_id = users.id 
       WHERE messages.room_id = $1 
       ORDER BY messages.created_at ASC`,
      [req.params.room_id]
    );
    res.json({ success: true, messages: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== СУДЬИ =====

app.post('/api/judge_votes', async (req, res) => {
  try {
    const { room_id, judge_user_id, performer_user_id, video_opened, comment } = req.body;
    const result = await pool.query(
      'INSERT INTO judge_votes (room_id, judge_user_id, performer_user_id, video_opened, comment) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [room_id, judge_user_id, performer_user_id, video_opened, comment]
    );
    res.json({ success: true, vote: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/judge-seats/:room_id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM judge_seats WHERE room_id = $1 ORDER BY seat_number',
      [req.params.room_id]
    );
    res.json({ success: true, seats: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/judge-seats/occupy', async (req, res) => {
  try {
    const { room_id, seat_number, user_id, coins } = req.body;
    const user = await pool.query('SELECT coins_balance FROM users WHERE id = $1', [user_id]);
    if (user.rows[0].coins_balance < coins) {
      return res.status(400).json({ success: false, error: 'Недостаточно монет' });
    }
    await pool.query(
      'UPDATE users SET coins_balance = coins_balance - $1 WHERE id = $2',
      [coins, user_id]
    );
    const result = await pool.query(
      'UPDATE judge_seats SET occupied_by_user_id = $1, paid_until = NOW() + INTERVAL \'1 hour\' WHERE room_id = $2 AND seat_number = $3 RETURNING *',
      [user_id, room_id, seat_number]
    );
    res.json({ success: true, seat: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== ОЧЕРЕДЬ =====

app.post('/api/queue/join', async (req, res) => {
  try {
    const { room_id, user_id } = req.body;
    const today = await pool.query(
      `SELECT COUNT(*) FROM queue 
       WHERE room_id = $1 AND user_id = $2 
       AND status = 'performed' 
       AND performed_date = CURRENT_DATE`,
      [room_id, user_id]
    );
    const performedCount = parseInt(today.rows[0].count);
    if (performedCount >= 5) {
      return res.status(400).json({
        success: false,
        error: 'Вы исчерпали лимит выступлений на сегодня (5). Возвращайтесь завтра!',
        limitReached: true,
      });
    }
    const existing = await pool.query(
      'SELECT * FROM queue WHERE room_id = $1 AND user_id = $2 AND status = $3',
      [room_id, user_id, 'waiting']
    );
    if (existing.rows.length > 0) {
      return res.json({ success: true, message: 'Вы уже в очереди', position: existing.rows[0].position });
    }
    const maxPos = await pool.query(
      'SELECT COALESCE(MAX(position), 0) as max_pos FROM queue WHERE room_id = $1 AND status = $2',
      [room_id, 'waiting']
    );
    const newPosition = maxPos.rows[0].max_pos + 1;
    const result = await pool.query(
      'INSERT INTO queue (room_id, user_id, position) VALUES ($1, $2, $3) RETURNING *',
      [room_id, user_id, newPosition]
    );
    res.json({ success: true, queue: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/queue/:room_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT queue.*, users.name as user_name 
       FROM queue 
       JOIN users ON queue.user_id = users.id 
       WHERE queue.room_id = $1 AND queue.status = 'waiting'
       ORDER BY queue.position ASC`,
      [req.params.room_id]
    );
    res.json({ success: true, queue: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/queue/start-performance', async (req, res) => {
  try {
    const { room_id, user_id } = req.body;
    await pool.query(
      'UPDATE queue SET is_performing = FALSE WHERE room_id = $1',
      [room_id]
    );
    await pool.query(
      "UPDATE queue SET is_performing = TRUE WHERE room_id = $1 AND user_id = $2 AND status = 'waiting'",
      [room_id, user_id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/queue/end-performance', async (req, res) => {
  try {
    const { room_id } = req.body;
    await pool.query(
      "UPDATE queue SET status = 'performed', is_performing = FALSE, performed_date = CURRENT_DATE WHERE room_id = $1 AND is_performing = TRUE",
      [room_id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/queue/current/:room_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT queue.*, users.name as user_name 
       FROM queue 
       JOIN users ON queue.user_id = users.id 
       WHERE queue.room_id = $1 AND queue.is_performing = TRUE
       LIMIT 1`,
      [req.params.room_id]
    );
    res.json({ success: true, performer: result.rows[0] || null });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/queue/check-limit', async (req, res) => {
  try {
    const { room_id, user_id } = req.body;
    const today = await pool.query(
      `SELECT COUNT(*) FROM queue 
       WHERE room_id = $1 AND user_id = $2 
       AND status = 'performed' 
       AND performed_date = CURRENT_DATE`,
      [room_id, user_id]
    );
    const count = parseInt(today.rows[0].count);
    let cost = 0;
    res.json({ success: true, count, cost, limit: 5 });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== СЕЗОНЫ =====

app.get('/api/seasons/current', async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM seasons WHERE status = 'active' ORDER BY start_date DESC LIMIT 1"
    );
    res.json({ success: true, season: result.rows[0] || null });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/seasons', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM seasons ORDER BY start_date DESC');
    res.json({ success: true, seasons: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/seasons', async (req, res) => {
  try {
    const { name, start_date, end_date, prize_description } = req.body;
    const result = await pool.query(
      'INSERT INTO seasons (name, start_date, end_date, prize_description) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, start_date, end_date, prize_description]
    );
    res.json({ success: true, season: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/seasons/:season_id/leaderboard', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT users.id, users.name, COUNT(judge_votes.id) as votes
       FROM users
       LEFT JOIN judge_votes ON judge_votes.performer_user_id = users.id
       WHERE judge_votes.room_id IN (SELECT id FROM rooms WHERE season_id = $1)
       GROUP BY users.id, users.name
       ORDER BY votes DESC
       LIMIT 10`,
      [req.params.season_id]
    );
    res.json({ success: true, leaderboard: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ===== SHORTS =====

app.get('/api/shorts', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT shorts.*, users.name as user_name 
       FROM shorts 
       JOIN users ON shorts.user_id = users.id 
       ORDER BY shorts.created_at DESC 
       LIMIT 50`
    );
    res.json({ success: true, shorts: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/shorts/:id/like', async (req, res) => {
  try {
    const { user_id } = req.body;
    const shortId = req.params.id;
    const existing = await pool.query(
      'SELECT * FROM shorts_likes WHERE user_id = $1 AND short_id = $2',
      [user_id, shortId]
    );
    if (existing.rows.length > 0) {
      await pool.query('DELETE FROM shorts_likes WHERE user_id = $1 AND short_id = $2', [user_id, shortId]);
      await pool.query('UPDATE shorts SET likes_count = likes_count - 1 WHERE id = $1', [shortId]);
      res.json({ success: true, liked: false });
    } else {
      await pool.query('INSERT INTO shorts_likes (user_id, short_id) VALUES ($1, $2)', [user_id, shortId]);
      await pool.query('UPDATE shorts SET likes_count = likes_count + 1 WHERE id = $1', [shortId]);
      res.json({ success: true, liked: true });
    }
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.listen(port, () => {
  console.log(`🚀 Сервер запущен на http://localhost:${port}`);
});