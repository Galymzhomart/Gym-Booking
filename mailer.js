// mailer.js (Ruslan). Sends the password-reset e-mail to a TEST mailbox.
// MAIL_MODE:
//   outbox   (default) writes outbox/<time>-<user>.eml and outbox/latest-reset-link.txt. No network needed.
//   ethereal           creates a free Ethereal test account on first use; the preview URL is printed to the console.
//   smtp               real SMTP server, e.g. Mailpit on localhost:1025 (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SECURE).
// Outbox files and console links contain a working reset link: use them for tests only, never in production.
const fs = require("fs");
const path = require("path");
const nodemailer = require("nodemailer");

const OUTBOX_DIR = path.join(__dirname, "outbox");

const texts = {
  kk: {
    subject: "Құпиясөзді қалпына келтіру",
    intro: "Gym Booking жүйесінде құпиясөзді қалпына келтіру сұралды.",
    action: "Жаңа құпиясөз орнату үшін сілтемені ашыңыз:",
    ttl: (m) => `Сілтеме ${m} минут жарамды және бір рет қана қолданылады.`,
    ignore: "Бұл сұрауды сіз жасамаған болсаңыз, хатты елемеңіз: құпиясөз өзгермейді.",
    button: "Құпиясөзді өзгерту"
  },
  ru: {
    subject: "Восстановление пароля",
    intro: "В системе Gym Booking запрошено восстановление пароля.",
    action: "Чтобы задать новый пароль, откройте ссылку:",
    ttl: (m) => `Ссылка действует ${m} минут и срабатывает один раз.`,
    ignore: "Если вы не запрашивали восстановление, проигнорируйте письмо: пароль не изменится.",
    button: "Задать новый пароль"
  },
  en: {
    subject: "Password recovery",
    intro: "A password reset was requested for your Gym Booking account.",
    action: "Open this link to set a new password:",
    ttl: (m) => `The link is valid for ${m} minutes and works once.`,
    ignore: "If you did not request this, ignore this e-mail: your password stays the same.",
    button: "Set a new password"
  }
};

function createMailer(env = process.env) {
  const mode = String(env.MAIL_MODE || "outbox").toLowerCase();
  const from = env.MAIL_FROM || "Gym Booking <no-reply@gym.test>";
  let transportPromise = null;

  function getTransport() {
    if (transportPromise) return transportPromise;
    if (mode === "smtp") {
      if (!env.SMTP_HOST) throw new Error("MAIL_MODE=smtp needs SMTP_HOST");
      transportPromise = Promise.resolve(nodemailer.createTransport({
        host: env.SMTP_HOST,
        port: Number(env.SMTP_PORT || 1025),
        secure: env.SMTP_SECURE === "true",
        auth: env.SMTP_USER ? { user: env.SMTP_USER, pass: env.SMTP_PASS || "" } : undefined,
        connectionTimeout: 8000, greetingTimeout: 8000, socketTimeout: 15000
      }));
    } else if (mode === "ethereal") {
      transportPromise = nodemailer.createTestAccount().then(acc => {
        console.log(`Ethereal test mailbox created: ${acc.user} (web: https://ethereal.email/login)`);
        return nodemailer.createTransport({
          host: acc.smtp.host, port: acc.smtp.port, secure: acc.smtp.secure,
          auth: { user: acc.user, pass: acc.pass },
          connectionTimeout: 8000, greetingTimeout: 8000, socketTimeout: 15000
        });
      });
    } else if (mode === "outbox") {
      transportPromise = Promise.resolve(nodemailer.createTransport({ streamTransport: true, buffer: true, newline: "unix" }));
    } else {
      throw new Error(`Unknown MAIL_MODE: ${mode}`);
    }
    transportPromise.catch(() => { transportPromise = null; });
    return transportPromise;
  }

  async function sendResetEmail({ to, username, link, lang, ttlMinutes }) {
    const t = texts[lang] || texts.ru;
    const transport = await getTransport();
    const text = [t.intro, "", t.action, link, "", t.ttl(ttlMinutes), t.ignore].join("\n");
    const html = `<p>${t.intro}</p><p>${t.action}</p><p><a href="${link}">${t.button}</a></p>`
               + `<p>${t.ttl(ttlMinutes)}</p><p>${t.ignore}</p>`;
    const info = await transport.sendMail({ from, to, subject: t.subject, text, html });

    if (mode === "outbox") {
      fs.mkdirSync(OUTBOX_DIR, { recursive: true });
      const stamp = new Date().toISOString().replace(/[:.]/g, "-");
      const safeName = String(username).replace(/[^a-z0-9_-]/gi, "_");
      fs.writeFileSync(path.join(OUTBOX_DIR, `${stamp}-${safeName}.eml`), info.message);
      fs.writeFileSync(path.join(OUTBOX_DIR, "latest-reset-link.txt"), `${to}\n${link}\n`);
    } else if (mode === "ethereal") {
      console.log("Reset e-mail preview:", nodemailer.getTestMessageUrl(info));
    }
    return { mode };
  }

  return { mode, sendResetEmail };
}

module.exports = { createMailer, OUTBOX_DIR };
