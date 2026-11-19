require("dotenv").config();

const express = require("express");
const session = require("express-session");
const PgSession = require("connect-pg-simple")(session);
const { Pool } = require("pg");
const path = require("path");
const { twofaRoutes, PENDING_TTL_MS } = require("./twofa_routes");

const { passwordRoutes } = require("./password_routes");
const { resetMessages } = require("./reset_messages");
const { createMailer } = require("./mailer");

const app = express();
const isProduction = process.env.NODE_ENV === "production";

const requiredEnv = ["SESSION_SECRET", "DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD"];
for (const key of requiredEnv) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
  }
}

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: true } : false,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000
});

app.disable("x-powered-by");
if (isProduction) app.set("trust proxy", 1);

app.use(express.json({ limit: "20kb" }));
app.use(express.urlencoded({ extended: false }));
app.use(session({
  store: new PgSession({ pool, tableName: "app_sessions", createTableIfMissing: false }),
  name: "gym.sid",
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: isProduction,
    sameSite: "strict",
    maxAge: 8 * 60 * 60 * 1000
  }
}));
const supportedLanguages = new Set(["kk", "ru", "en"]);
app.use((req, _res, next) => {
  const requested = String(req.get("Accept-Language") || "ru").split(",")[0].trim().slice(0, 2).toLowerCase();
  req.lang = supportedLanguages.has(requested) ? requested : "ru";
  next();
});
app.use(express.static(path.join(__dirname, "public")));

const serverMessages = {
  kk: {loginRequired:"Алдымен жүйеге кіріңіз.", forbidden:"Бұл әрекетті орындауға құқығыңыз жоқ.", enterCredentials:"Логин мен құпиясөзді енгізіңіз.", invalidCredentials:"Логин немесе құпиясөз қате.", enterSession:"Жаттығуды таңдаңыз.", booked:"Бұл жаттығу әлдеқашан брондалған.", overlap:"Бұл уақытта сізде басқа жаттығу бар.", membership:"Абонементіңіз белсенді емес.", expiry:"Абонемент жаттығу күніне дейін жарамды болмайды.", past:"Өтіп кеткен жаттығуға жазылу мүмкін емес.", trainer:"Бұл жаттықтырушы қазір жазылуды қабылдамайды.", cancel:"Жаттығу басталғаннан кейін жазылудан бас тартуға болмайды.", attendance:"Қатысуды тек жаттығу аяқталғаннан кейін белгілеуге болады.", transition:"Бұл күй өзгерісіне рұқсат жоқ.", permission:"Дерекқор рұқсаттары бұл әрекетке тыйым салады.", unavailable:"Таңдалған деректер қолжетімсіз. Бетті жаңартыңыз.", overlapTrainer:"Жаттықтырушының уақыты басқа жаттығумен қабаттасады.", db:"Дерекқорға қосылу мүмкін болмады. Кейінірек қайталап көріңіз.", generic:"Әрекетті орындау мүмкін болмады. Деректерді тексеріп, қайталап көріңіз.", logout:"Сеансты аяқтау мүмкін болмады.", notFound:"Белсенді жазылу табылмады.", bookingSaved:"Жазылу сәтті сақталды.", bookingCancelled:"Жазылу тоқтатылды. Тарих сақталды.", attendanceUpdated:"Қатысу күйі жаңартылды.", invalidStatus:"Рұқсат етілген күйлер: Attended немесе No-show.", bookingNotOwned:"Жазылу табылмады, тоқтатылған немесе сізге тиесілі емес.", internal:"Серверде ішкі қате пайда болды."},
  ru: {loginRequired:"Сначала войдите в систему.", forbidden:"У вас нет прав для этого действия.", enterCredentials:"Введите логин и пароль.", invalidCredentials:"Неверный логин или пароль.", enterSession:"Выберите тренировку.", booked:"Это занятие уже забронировано.", overlap:"У вас уже есть тренировка в это время.", membership:"Ваш абонемент не активен.", expiry:"Абонемент закончится раньше даты тренировки.", past:"Нельзя бронировать прошедшее занятие.", trainer:"Этот тренер сейчас не принимает бронирования.", cancel:"Отменить можно только до начала тренировки.", attendance:"Посещаемость можно отметить только после окончания тренировки.", transition:"Это изменение статуса недопустимо.", permission:"Операция запрещена настройками доступа.", unavailable:"Выбранные данные больше недоступны. Обновите страницу.", overlapTrainer:"Время тренера пересекается с другим занятием.", db:"Не удалось подключиться к базе данных. Попробуйте позже.", generic:"Не удалось выполнить действие. Проверьте данные и попробуйте ещё раз.", logout:"Не удалось завершить сеанс.", notFound:"Активное бронирование не найдено.", bookingSaved:"Бронирование успешно сохранено.", bookingCancelled:"Бронирование отменено. История сохранена.", attendanceUpdated:"Посещаемость обновлена.", invalidStatus:"Допустимые статусы: Attended или No-show.", bookingNotOwned:"Бронирование не найдено, уже отменено или не принадлежит вам.", internal:"Внутренняя ошибка сервера."},
  en: {loginRequired:"Please sign in first.", forbidden:"You are not allowed to perform this action.", enterCredentials:"Enter your username and password.", invalidCredentials:"Incorrect username or password.", enterSession:"Choose a training session.", booked:"This session has already been booked.", overlap:"You already have another session at this time.", membership:"Your membership is not active.", expiry:"Your membership expires before the session date.", past:"Past sessions cannot be booked.", trainer:"This trainer is not accepting bookings right now.", cancel:"A booking can only be cancelled before the session starts.", attendance:"Attendance can only be marked after the session ends.", transition:"This status change is not allowed.", permission:"This operation is denied by database permissions.", unavailable:"The selected data is no longer available. Refresh the page.", overlapTrainer:"The trainer's time overlaps with another session.", db:"Could not connect to the database. Please try again later.", generic:"The action could not be completed. Check the details and try again.", logout:"Could not end the session.", notFound:"No active booking was found.", bookingSaved:"Booking saved successfully.", bookingCancelled:"Booking cancelled. History was preserved.", attendanceUpdated:"Attendance updated.", invalidStatus:"Allowed statuses: Attended or No-show.", bookingNotOwned:"Booking was not found, is cancelled, or does not belong to you.", internal:"An internal server error occurred."}
};
const twofaMessages = {
  "kk": {
    "twofaExpired": "Код енгізу уақыты аяқталды. Қайта кіріңіз.",
    "twofaFormat": "Код 6 цифрдан тұрады.",
    "twofaLocked": "Әрекет тым көп. 5 минуттан кейін қайта кіріңіз.",
    "twofaNotEnrolled": "Бұл аккаунтта екі факторлы қорғау қосылмаған.",
    "twofaInvalid": "Код қате. Қайта енгізіңіз."
  },
  "ru": {
    "twofaExpired": "Время ввода кода истекло. Войдите заново.",
    "twofaFormat": "Код состоит из 6 цифр.",
    "twofaLocked": "Слишком много попыток. Подождите 5 минут и войдите заново.",
    "twofaNotEnrolled": "Для этого аккаунта не подключена двухфакторная защита.",
    "twofaInvalid": "Неверный код. Попробуйте ещё раз."
  },
  "en": {
    "twofaExpired": "The verification step expired. Sign in again.",
    "twofaFormat": "Enter a six-digit code.",
    "twofaLocked": "Too many attempts. Wait five minutes and sign in again.",
    "twofaNotEnrolled": "Two-factor authentication is not set up for this account.",
    "twofaInvalid": "Incorrect code. Try again."
  }
};

function message(req, key) {
  return serverMessages[req.lang]?.[key]
    || twofaMessages[req.lang]?.[key]
    || resetMessages[req.lang]?.[key]
    || serverMessages.ru[key]
    || twofaMessages.ru[key]
    || resetMessages.ru[key]
    || key;
}

function requireAuth(req, res, next) {
  if (!req.session.user) return res.status(401).json({
      error: message(req, "loginRequired"),
      code: req.session.pending2fa ? "2FA_REQUIRED" : "AUTH_REQUIRED"
    });
  next();
}
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.session.user) return res.status(401).json({
      error: message(req, "loginRequired"),
      code: req.session.pending2fa ? "2FA_REQUIRED" : "AUTH_REQUIRED"
    });
    if (!roles.includes(req.session.user.role)) {
      return res.status(403).json({ error: message(req, "forbidden") });
    }
    next();
  };
}
function friendlyError(err, req) {
  const msg = String(err.message || "");
  let key = "generic";
  if (msg.includes("one_non_cancelled_booking_per_session") || msg.includes("duplicate key")) key = "booked";
  else if (msg.includes("Member already has a booking that overlaps")) key = "overlap";
  else if (msg.includes("Membership must be active")) key = "membership";
  else if (msg.includes("Membership expires before")) key = "expiry";
  else if (msg.includes("Cannot book a session in the past")) key = "past";
  else if (msg.includes("Trainer is not active")) key = "trainer";
  else if (msg.includes("Cannot cancel")) key = "cancel";
  else if (msg.includes("session has not ended")) key = "attendance";
  else if (msg.includes("Status transition") || msg.includes("Booking history cannot be changed")) key = "transition";
  else if (msg.includes("permission denied")) key = "permission";
  else if (err.code === "23503") key = "unavailable";
  else if (err.code === "23P01") key = "overlapTrainer";
  else if (["ECONNREFUSED", "ETIMEDOUT", "08001"].includes(err.code)) key = "db";
  return message(req, key);
}
function handleDbError(res, err, status = 400) {
  console.error("Database operation failed:", err.code || "no-code", err.message);
  res.status(status).json({ error: friendlyError(err, res.req) });
}

// Login is checked by Shokan's database function. The app role cannot read app_users.
app.post("/api/login", async (req, res) => {
  const username = String(req.body.username || "").trim().toLowerCase();
  const password = String(req.body.password || "");
  if (!username || !password || username.length > 50 || password.length > 200) {
    return res.status(400).json({ error: message(req, "enterCredentials") });
  }
  try {
    const result = await pool.query("SELECT * FROM app_login($1, $2)", [username, password]);
    if (!result.rows.length) return res.status(401).json({ error: message(req, "invalidCredentials") });
    const user = result.rows[0];
    // 2FA: the password is correct, but the user is NOT logged in yet.
    const enrolled = await pool.query("SELECT app_totp_enabled($1) AS enabled", [user.user_id]);
    if (!enrolled.rows[0].enabled) {
      return res.status(403).json({ error: message(req, "twofaNotEnrolled"), code: "2FA_NOT_ENROLLED" });
    }
    await new Promise((resolve, reject) => req.session.regenerate(err => err ? reject(err) : resolve()));
    req.session.pending2fa = {
      userId: user.user_id,
      role: user.role,
      memberId: user.member_id,
      expiresAt: Date.now() + PENDING_TTL_MS,
      attempts: 0
    };
    req.session.cookie.maxAge = PENDING_TTL_MS;   // short life until the code is accepted
    res.json({ twoFactorRequired: true, code: "2FA_REQUIRED" });
  } catch (err) {
    handleDbError(res, err, 503);
  }
});

// Password reset UI contract. The token workflow is provided by Ruslan's backend module.
app.post("/api/logout", (req, res) => {
  req.session.destroy(err => {
    if (err) return res.status(500).json({ error: message(req, "logout") });
    res.clearCookie("gym.sid", { httpOnly: true, sameSite: "strict", secure: isProduction });
    res.json({ ok: true });
  });
});

app.use("/api", twofaRoutes(pool, isProduction, message));

app.use("/api", passwordRoutes(pool, message, createMailer()));

app.get("/api/me", (req, res) => {
  const p = req.session.pending2fa;
  res.json({ user: req.session.user || null, pending: !req.session.user && !!p && Date.now() < p.expiresAt });
});

app.get("/api/sessions", requireAuth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT so.session_id, so.trainer_name AS trainer,
             public.tr('specialization', so.specialization, $1) AS specialization,
             so.start_time, so.end_time, public.tr('location', so.location, $1) AS location,
             so.is_booked,
             (m.membership_status = 'Active' AND m.membership_expiry >= (so.start_time AT TIME ZONE 'Asia/Almaty')::date) AS membership_valid,
             CASE WHEN so.is_booked THEN 'occupied'
                  WHEN NOT (m.membership_status = 'Active' AND m.membership_expiry >= (so.start_time AT TIME ZONE 'Asia/Almaty')::date) THEN 'unavailable'
                  WHEN EXISTS (
                        SELECT 1
                        FROM public.bookings b
                        JOIN public.sessions bs ON bs.session_id = b.session_id
                        WHERE b.member_id = $2
                              AND b.status <> 'Cancelled'
                              AND bs.start_time < so.end_time
                              AND bs.end_time > so.start_time
                  ) THEN 'unavailable'
                  ELSE 'free' END AS slot_status
      FROM public.sessions_overview so
      JOIN public.members m ON m.member_id = $2
      WHERE so.start_time > now() AND so.trainer_active
      ORDER BY so.start_time
    `, [req.lang, req.session.user.memberId]);
    res.json({ sessions: result.rows });
  } catch (err) { handleDbError(res, err, 503); }
});

app.get("/api/sessions/:id/nearest", requireRole("Member"), async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT ns.session_id,
             ns.trainer_name AS trainer,
             ns.start_time,
             ns.end_time,
             public.tr('location', ns.location, $3) AS location
      FROM public.app_nearest_session($1, $2) ns
    `, [req.session.user.memberId, req.params.id, req.lang]);

    res.json({ session: result.rows[0] || null });
  } catch (err) {
    handleDbError(res, err, 503);
  }
});

app.get("/api/progress", requireRole("Member"), async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT week_start,
             week_end,
             attended,
             goal AS target,
             remaining,
             percent
      FROM public.app_weekly_progress($1, 4)
    `, [req.session.user.memberId]);

    res.json({ progress: result.rows[0] });
  } catch (err) {
    handleDbError(res, err, 503);
  }
});

app.get("/api/bookings", requireAuth, async (req, res) => {
  try {
    const params = [req.lang];
    let where = "";
    if (req.session.user.role === "Member") {
      params.push(req.session.user.memberId);
      where = "WHERE b.member_id = $2";
    }
    const result = await pool.query(`
      SELECT b.booking_id, b.member_id, m.full_name AS member_name,
             b.session_id, t.full_name AS trainer, s.start_time, s.end_time,
             public.tr('location', s.location, $1) AS location, b.status, b.created_at
      FROM bookings b
      JOIN members m USING (member_id)
      JOIN sessions s USING (session_id)
      JOIN trainers t USING (trainer_id)
      ${where}
      ORDER BY s.start_time DESC, b.created_at DESC
    `, params);
    res.json({ bookings: result.rows });
  } catch (err) { handleDbError(res, err, 503); }
});

app.post("/api/bookings", requireRole("Member"), async (req, res) => {
  const sessionId = String(req.body.sessionId || "").trim();
  if (!sessionId || sessionId.length > 20) return res.status(400).json({ error: message(req, "enterSession") });
  try {
    const result = await pool.query(
      "INSERT INTO bookings (member_id, session_id) VALUES ($1, $2) RETURNING booking_id, status, session_id",
      [req.session.user.memberId, sessionId]
    );
    res.status(201).json({ booking: result.rows[0], message: message(req, "bookingSaved") });
  } catch (err) { handleDbError(res, err); }
});

app.post("/api/bookings/:id/cancel", requireRole("Member"), async (req, res) => {
  const bookingId = String(req.params.id || "");
  try {
    const result = await pool.query(`
      UPDATE bookings b
      SET status = 'Cancelled'
      WHERE b.booking_id = $1
        AND b.member_id = $2
        AND b.status = 'Confirmed'
      RETURNING b.booking_id, b.status
    `, [bookingId, req.session.user.memberId]);
    if (!result.rowCount) {
      return res.status(403).json({ error: message(req, "bookingNotOwned") });
    }
    res.json({ booking: result.rows[0], message: message(req, "bookingCancelled") });
  } catch (err) { handleDbError(res, err); }
});

app.post("/api/bookings/:id/attendance", requireRole("Reception"), async (req, res) => {
  const bookingId = String(req.params.id || "");
  const status = req.body.status;
  if (!["Attended", "No-show"].includes(status)) {
    return res.status(400).json({ error: message(req, "invalidStatus") });
  }
  try {
    const result = await pool.query(`
      UPDATE bookings SET status = $1
      WHERE booking_id = $2 AND status = 'Confirmed'
      RETURNING booking_id, status
    `, [status, bookingId]);
    if (!result.rowCount) return res.status(404).json({ error: message(req, "notFound") });
    res.json({ booking: result.rows[0], message: message(req, "attendanceUpdated") });
  } catch (err) { handleDbError(res, err); }
});

app.get("/api/health", async (_req, res) => {
  try {
    const result = await pool.query("SELECT current_user AS db_user, current_database() AS db_name, version()");
    res.json({ ok: true, database: result.rows[0].db_name, user: result.rows[0].db_user, postgres: result.rows[0].version.split(" ")[1] });
  } catch (_err) {
    res.status(503).json({ ok: false, error: "Database unavailable" });
  }
});

app.use((err, req, res, _next) => {
  console.error("Request failed:", err.message);
  res.status(500).json({ error: message(req, "internal") });
});

const port = Number(process.env.PORT || 3000);
const server = app.listen(port, () => console.log(`Gym Booking System is running on http://localhost:${port}`));
async function shutdown() {
  server.close();
  await pool.end();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
