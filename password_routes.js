// password_routes.js (Ruslan). "Forgot password?" scenario. Mounted in server.js as:
//   app.use("/api", passwordRoutes(pool, message, mailer));
// All checks of the token and the password change run inside PostgreSQL (app_password_reset_* functions).
// The token is random (256 bit), lives only in the e-mail link; the database keeps its SHA-256 hash.
// Every answer carries a short "code" so the interface can show the text in kk / ru / en.
//
// POST /api/password/forgot       {email}                         -> 200 RESET_SENT (same answer for known and unknown e-mail)
// POST /api/password/reset/check  {token}                         -> 200 {valid:true} | 400 RESET_INVALID | 410 RESET_EXPIRED | 410 RESET_USED
// POST /api/password/reset        {token, password, confirmPassword?} -> 200 PASSWORD_CHANGED | 400 PASSWORD_WEAK | 400 PASSWORD_SAME
//                                                                        | 400 PASSWORD_MISMATCH | 400/410 as above
const crypto = require("crypto");
const express = require("express");

const RESET_TTL_MINUTES = Math.min(Math.max(Number(process.env.RESET_TTL_MINUTES) || 30, 5), 1440);
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;     // base64url of 32 bytes

// Small in-memory limiter (one server process). The database adds its own limit of 3 links per hour per user.
function createLimiter(max, windowMs) {
  const hits = new Map();
  return (key) => {
    const now = Date.now();
    const list = (hits.get(key) || []).filter(ts => now - ts < windowMs);
    if (list.length >= max) { hits.set(key, list); return false; }
    list.push(now);
    hits.set(key, list);
    if (hits.size > 5000) for (const [k, v] of hits) if (!v.some(ts => now - ts < windowMs)) hits.delete(k);
    return true;
  };
}

const sha256 = (token) => crypto.createHash("sha256").update(token).digest();

function passwordProblem(password) {
  if (typeof password !== "string" || password.length < 8 || password.length > 200) return true;
  return !(/\p{L}/u.test(password) && /\d/.test(password));
}

function passwordRoutes(pool, message, mailer, options = {}) {
  const router = express.Router();
  const baseUrl = String(options.baseUrl || process.env.APP_BASE_URL || "http://localhost:3000").replace(/\/+$/, "");
  const ttl = options.ttlMinutes || RESET_TTL_MINUTES;
  const allowByIp = createLimiter(10, 15 * 60 * 1000);
  const allowByEmail = createLimiter(3, 15 * 60 * 1000);
  const allowConfirm = createLimiter(30, 15 * 60 * 1000);

  const fail = (req, res, status, code, key) => res.status(status).json({ error: message(req, key), code });
  const statusAnswer = (req, res, status) => {
    if (status === "expired") return fail(req, res, 410, "RESET_EXPIRED", "resetExpired");
    if (status === "used")    return fail(req, res, 410, "RESET_USED", "resetUsed");
    return fail(req, res, 400, "RESET_INVALID", "resetInvalid");
  };
  const readToken = (body) => {
    const token = String(body?.token ?? "").trim();
    return TOKEN_RE.test(token) ? token : null;
  };

  router.post("/password/forgot", async (req, res) => {
    const email = String(req.body?.email ?? "").trim().toLowerCase();
    if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
      return fail(req, res, 400, "EMAIL_FORMAT", "resetEmailFormat");
    }
    // The limiter looks only at the input, so it reveals nothing about which e-mails exist.
    if (!allowByIp(req.ip) || !allowByEmail(email)) {
      return fail(req, res, 429, "RESET_RATE_LIMITED", "resetRateLimited");
    }

    let row = null;
    const token = crypto.randomBytes(32).toString("base64url");
    try {
      const r = await pool.query("SELECT username, email FROM app_password_reset_request($1, $2, $3)",
        [email, sha256(token), ttl]);
      row = r.rows[0] || null;
    } catch (err) {
      console.error("Password reset request failed:", err.code || "no-code", err.message);
      return fail(req, res, 503, "SERVER_ERROR", "generic");
    }

    // Same answer whether or not an account exists. The e-mail is sent after the answer, so timing does not leak either.
    res.json({ ok: true, code: "RESET_SENT", message: message(req, "resetSent") });

    if (row) {
      const link = `${baseUrl}/#reset-password=${token}`;     // fragment: not sent to servers, not in logs or Referer
      mailer.sendResetEmail({ to: row.email, username: row.username, link, lang: req.lang, ttlMinutes: ttl })
        .then(() => {
          if (process.env.NODE_ENV !== "production") console.log(`Reset e-mail sent (${mailer.mode}) to ${row.email}`);
        })
        .catch(err => console.error("Reset e-mail failed:", err.message));
    }
  });

  router.post("/password/reset/check", async (req, res) => {
    const token = readToken(req.body);
    if (!token) return fail(req, res, 400, "RESET_INVALID", "resetInvalid");
    if (!allowConfirm(req.ip)) return fail(req, res, 429, "RESET_RATE_LIMITED", "resetRateLimited");
    try {
      const r = await pool.query("SELECT app_password_reset_check($1) AS status", [sha256(token)]);
      const status = r.rows[0].status;
      if (status === "valid") return res.json({ valid: true });
      return statusAnswer(req, res, status);
    } catch (err) {
      console.error("Password reset check failed:", err.code || "no-code", err.message);
      return fail(req, res, 503, "SERVER_ERROR", "generic");
    }
  });

  router.post("/password/reset", async (req, res) => {
    const token = readToken(req.body);
    if (!token) return fail(req, res, 400, "RESET_INVALID", "resetInvalid");
    if (!allowConfirm(req.ip)) return fail(req, res, 429, "RESET_RATE_LIMITED", "resetRateLimited");
    const password = req.body.password;
    if (req.body.confirmPassword !== undefined && req.body.confirmPassword !== password) {
      return fail(req, res, 400, "PASSWORD_MISMATCH", "passwordMismatch");
    }
    if (passwordProblem(password)) return fail(req, res, 400, "PASSWORD_WEAK", "passwordWeak");

    try {
      const r = await pool.query("SELECT app_password_reset_confirm($1, $2) AS status", [sha256(token), password]);
      const status = r.rows[0].status;
      if (status === "ok") return res.json({ ok: true, code: "PASSWORD_CHANGED", message: message(req, "passwordChanged") });
      if (status === "weak") return fail(req, res, 400, "PASSWORD_WEAK", "passwordWeak");
      if (status === "same") return fail(req, res, 400, "PASSWORD_SAME", "passwordSame");
      return statusAnswer(req, res, status);
    } catch (err) {
      console.error("Password reset failed:", err.code || "no-code", err.message);
      return fail(req, res, 503, "SERVER_ERROR", "generic");
    }
  });

  return router;
}

module.exports = { passwordRoutes, RESET_TTL_MINUTES };
