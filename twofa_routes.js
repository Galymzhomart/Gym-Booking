// twofa_routes.js (Ruslan). Second login step (TOTP). Mounted in server.js as: app.use("/api", twofaRoutes(pool, isProduction));
// The code is checked inside PostgreSQL by app_totp_verify(). The secret never reaches Node.
// Server answers carry a short "code" so the interface can show the text in kk / ru / en.
const express = require("express");

const PENDING_TTL_MS = 5 * 60 * 1000;   // time allowed for the second step
const MAX_PENDING_ATTEMPTS = 5;          // wrong codes per password step (the database also counts per user)

function twofaRoutes(pool, isProduction, message) {
  const router = express.Router();

  function destroySession(req, res, status, body) {
    req.session.destroy(() => {
      res.clearCookie("gym.sid", { httpOnly: true, sameSite: "strict", secure: isProduction });
      res.status(status).json(body);
    });
  }

  router.post("/login/2fa", async (req, res) => {
    const pending = req.session.pending2fa;
    if (!pending || req.session.user) {
      return res.status(401).json({ error: message(req, "twofaExpired"), code: "2FA_EXPIRED" });
    }
    if (Date.now() > pending.expiresAt) {
      return destroySession(req, res, 401, { error: message(req, "twofaExpired"), code: "2FA_EXPIRED" });
    }

    const code = String(req.body.code ?? "").replace(/\s/g, "");
    if (!/^\d{6}$/.test(code)) {
      return res.status(400).json({ error: message(req, "twofaFormat"), code: "CODE_FORMAT" });
    }

    let result;
    try {
      const r = await pool.query("SELECT app_totp_verify($1, $2) AS result", [pending.userId, code]);
      result = r.rows[0].result;
    } catch (err) {
      console.error("2FA check failed:", err.code || "no-code", err.message);
      return res.status(503).json({ error: message(req, "generic"), code: "SERVER_ERROR" });
    }

    if (result === "ok") {
      try {
        const user = { userId: pending.userId, role: pending.role, memberId: pending.memberId };
        await new Promise((resolve, reject) => req.session.regenerate(e => e ? reject(e) : resolve()));
        req.session.user = user;            // new session id, normal 8 h cookie, no pending data
        return res.json({ user });
      } catch (err) {
        console.error("2FA session failed:", err.message);
        return res.status(500).json({ error: message(req, "internal"), code: "SERVER_ERROR" });
      }
    }
    if (result === "locked") {
      return destroySession(req, res, 429, { error: message(req, "twofaLocked"), code: "2FA_LOCKED" });
    }
    if (result === "not_enrolled") {
      return destroySession(req, res, 403, { error: message(req, "twofaNotEnrolled"), code: "2FA_NOT_ENROLLED" });
    }
    // "invalid" and "replay" look the same to the client.
    pending.attempts = (pending.attempts || 0) + 1;
    if (pending.attempts >= MAX_PENDING_ATTEMPTS) {
      return destroySession(req, res, 429, { error: message(req, "twofaLocked"), code: "2FA_LOCKED" });
    }
    return res.status(401).json({ error: message(req, "twofaInvalid"), code: "2FA_INVALID" });
  });

  return router;
}

module.exports = { twofaRoutes, PENDING_TTL_MS };
