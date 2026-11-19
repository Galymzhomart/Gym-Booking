const $ = (id) => document.getElementById(id);
const translations = {
  kk: {
    language:"Тіл", logout:"Шығу", heroEyebrow:"ЖЕКЕ ЖАТТЫҒУЛАР · ЖАЗЫЛУ", heroTitle:"Сенің жаттығуың.<br><span>Сенің уақытың.</span>",
    heroCopy:"Бос жаттығуды таңдап, жазылып, жаттығуларыңды бір жерден басқар.", point1:"01 / Уақытты таңда", point2:"02 / Жазылуды раста", point3:"03 / Жаттығуға кел",
    welcomeBack:"ҚАЙТА ҚОШ КЕЛДІҢІЗ", loginTitle:"Жүйеге кіру", username:"Логин", password:"Құпиясөз", usernamePlaceholder:"Логинді енгізіңіз", passwordPlaceholder:"Құпиясөзді енгізіңіз",
    login:"Кіру", forgotPassword:"Құпиясөзді ұмыттыңыз ба?", accountRecovery:"АККАУНТТЫ ҚАЛПЫНА КЕЛТІРУ", forgotTitle:"Құпиясөзді қалпына келтіру", forgotCopy:"Аккаунтыңызға тіркелген email мекенжайын енгізіңіз. Қалпына келтіру сілтемесін жібереміз.", sendResetLink:"Сілтемені жіберу", newPasswordTitle:"Жаңа құпиясөз", newPasswordCopy:"Аккаунтыңызға жаңа құпиясөз орнатыңыз.", newPassword:"Жаңа құпиясөз", confirmPassword:"Құпиясөзді қайталаңыз", savePassword:"Құпиясөзді сақтау", myProgress:"МЕНІҢ ПРОГРЕСІМ", weeklyProgress:"Апталық прогресс", onlyAvailableToMe:"Маған қолжетімділері ғана", statusFree:"Бос", statusOccupied:"Бос емес", statusUnavailable:"Қолжетімсіз", findNearest:"Ең жақын жаттығуды табу", nearestFound:"Ұсынылған ең жақын уақыт", noNearest:"Сәйкес келетін жаттығу табылмады.", confirmNearest:"Осы уақытқа жазылуды растайсыз ба?", passwordMismatch:"Құпиясөздер сәйкес келмейді.", resetLinkSent:"Егер бұл email тіркелген болса, қалпына келтіру сілтемесі жіберілді.", demoNote:"Демо тіркелгілер мен құпиясөздер demo_seed.sql орындалғаннан кейін README файлында көрсетілген.",
    securityEyebrow:"АККАУНТ ҚАУІПСІЗДІГІ", twofaHero:"Кіруді растаңыз", twofaCopy:"Аккаунтқа кіруді аяқтау үшін бір реттік кодты енгізіңіз.",
    secondStep:"ЕКІНШІ ҚАДАМ", twofaTitle:"Екі факторлы тексеру", otpCode:"Растау коды", otpPlaceholder:"Кодты енгізіңіз", verify:"Растау", backToLogin:"Кіру бетіне оралу",
    dbConnected:"PostgreSQL қосылған", availableSessions:"Бос жаттығулар", bookings:"Жазылулар", chooseTraining:"Жаттығуды таңда", futureSessions:"Белсенді жаттықтырушылардың алдағы жаттығулары көрсетіледі.",
    refresh:"Жаңарту ↻", cancelledHistory:"Бас тартылған жазбалар тарихта сақталады.", memberTitle:"Сенің жаттығуларың", receptionTitle:"Әкімші панелі",
    memberCopy:"Жаттығуларыңды басқар және кестеңді бақыла.", receptionCopy:"Барлық жазылуларды және келушілерді басқар.", myBookings:"Менің жазылуларым", allBookings:"Барлық жазылулар",
    loadingSessions:"Кесте жүктелуде…", noSessions:"Қазір бос алдағы жаттығулар жоқ.", loadingBookings:"Жазылулар жүктелуде…", noBookings:"Әзірге жазылулар жоқ.",
    book:"Жазылу →", booked:"Орын бос емес", bookedReason:"Бұл жаттығуда бос орын жоқ — басқа қатысушы брондап қойған.", free:"Бос", trainer:"Жаттықтырушы", booking:"Жазылу",
    bookingSuccess:"Жазылу сәтті сақталды.", bookingNumber:"Жазылу нөмірі", cancel:"Бас тарту", cancelConfirm:"Жазылудан бас тартасыз ба? Жазба тарихта қалады.",
    cancelled:"Жазылу тоқтатылды. Тарих сақталды.", attended:"Қатысты", noShow:"Келмеді", markAttended:"Қатысты", markNoShow:"Келмеді", attendanceUpdated:"Қатысу күйі жаңартылды.",
    statusConfirmed:"Расталды", statusCancelled:"Бас тартылды", statusAttended:"Қатысты", statusNoShow:"Келмеді", bookingLabel:"Жазылу", logoutFailed:"Сеансты аяқтау мүмкін болмады."
  },
  ru: {
    language:"Язык", logout:"Выйти", heroEyebrow:"PERSONAL TRAINING · BOOKING", heroTitle:"Твоя тренировка.<br><span>Твоё время.</span>",
    heroCopy:"Выбирай свободное занятие, бронируй и управляй своими тренировками в одном месте.", point1:"01 / Выбери время", point2:"02 / Подтверди запись", point3:"03 / Приходи на тренировку",
    welcomeBack:"WELCOME BACK", loginTitle:"Войти в систему", username:"Логин", password:"Пароль", usernamePlaceholder:"Введите логин", passwordPlaceholder:"Введите пароль",
    login:"Войти", forgotPassword:"Забыли пароль?", accountRecovery:"ВОССТАНОВЛЕНИЕ АККАУНТА", forgotTitle:"Восстановление пароля", forgotCopy:"Укажите email, привязанный к аккаунту. Мы отправим ссылку для сброса пароля.", sendResetLink:"Отправить ссылку", newPasswordTitle:"Новый пароль", newPasswordCopy:"Создайте новый пароль для своего аккаунта.", newPassword:"Новый пароль", confirmPassword:"Повторите пароль", savePassword:"Сохранить пароль", myProgress:"МОЙ ПРОГРЕСС", weeklyProgress:"Прогресс за неделю", onlyAvailableToMe:"Только доступные мне", statusFree:"Свободно", statusOccupied:"Занято", statusUnavailable:"Недоступно", findNearest:"Найти ближайшее занятие", nearestFound:"Ближайшее подходящее время", noNearest:"Подходящих занятий не найдено.", confirmNearest:"Подтвердить бронирование на это время?", passwordMismatch:"Пароли не совпадают.", resetLinkSent:"Если этот email зарегистрирован, ссылка для сброса пароля отправлена.", demoNote:"Демо-аккаунты и пароли указаны в README после запуска demo_seed.sql.",
    securityEyebrow:"ACCOUNT SECURITY", twofaHero:"Подтвердите вход", twofaCopy:"Введите одноразовый код, чтобы завершить вход в аккаунт.",
    secondStep:"SECOND STEP", twofaTitle:"Двухфакторная проверка", otpCode:"Код подтверждения", otpPlaceholder:"Введите код", verify:"Подтвердить", backToLogin:"Вернуться ко входу",
    dbConnected:"PostgreSQL connected", availableSessions:"Свободные занятия", bookings:"Бронирования", chooseTraining:"Выбери тренировку", futureSessions:"Показываются будущие занятия активных тренеров.",
    refresh:"Обновить ↻", cancelledHistory:"Отменённые записи остаются в истории.", memberTitle:"Твои тренировки", receptionTitle:"Панель администратора",
    memberCopy:"Управляй своими занятиями и следи за расписанием.", receptionCopy:"Управляйте всеми бронированиями и посещаемостью.", myBookings:"Мои бронирования", allBookings:"Все бронирования",
    loadingSessions:"Загружаем расписание…", noSessions:"Сейчас нет будущих занятий.", loadingBookings:"Загружаем бронирования…", noBookings:"Бронирований пока нет.",
    book:"Забронировать →", booked:"Место занято", bookedReason:"Свободных мест нет — другой участник уже забронировал это занятие.", free:"Свободно", trainer:"Тренер", booking:"Бронь",
    bookingSuccess:"Бронирование успешно сохранено.", bookingNumber:"Номер брони", cancel:"Отменить", cancelConfirm:"Отменить бронирование? Запись останется в истории.",
    cancelled:"Бронирование отменено. История сохранена.", attended:"Посетил", noShow:"Не пришёл", markAttended:"Посетил", markNoShow:"Не пришёл", attendanceUpdated:"Посещаемость обновлена.",
    statusConfirmed:"Подтверждено", statusCancelled:"Отменено", statusAttended:"Посетил", statusNoShow:"Не пришёл", bookingLabel:"Бронь", logoutFailed:"Не удалось завершить сеанс."
  },
  en: {
    language:"Language", logout:"Log out", heroEyebrow:"PERSONAL TRAINING · BOOKING", heroTitle:"Your training.<br><span>Your time.</span>",
    heroCopy:"Choose an available session, book it, and manage your training in one place.", point1:"01 / Choose a time", point2:"02 / Confirm your booking", point3:"03 / Attend your session",
    welcomeBack:"WELCOME BACK", loginTitle:"Sign in", username:"Username", password:"Password", usernamePlaceholder:"Enter username", passwordPlaceholder:"Enter password",
    login:"Sign in", forgotPassword:"Forgot password?", accountRecovery:"ACCOUNT RECOVERY", forgotTitle:"Reset password", forgotCopy:"Enter the email linked to your account. We will send a password reset link.", sendResetLink:"Send reset link", newPasswordTitle:"New password", newPasswordCopy:"Create a new password for your account.", newPassword:"New password", confirmPassword:"Confirm password", savePassword:"Save password", myProgress:"MY PROGRESS", weeklyProgress:"Weekly progress", onlyAvailableToMe:"Only show sessions available to me", statusFree:"Available", statusOccupied:"Occupied", statusUnavailable:"Unavailable", findNearest:"Find nearest session", nearestFound:"Nearest available option", noNearest:"No suitable sessions were found.", confirmNearest:"Confirm booking for this time?", passwordMismatch:"Passwords do not match.", resetLinkSent:"If this email is registered, a reset link has been sent.", demoNote:"Demo accounts and passwords are listed in README after running demo_seed.sql.",
    securityEyebrow:"ACCOUNT SECURITY", twofaHero:"Verify your sign-in", twofaCopy:"Enter the one-time code to finish signing in to your account.",
    secondStep:"SECOND STEP", twofaTitle:"Two-factor verification", otpCode:"Verification code", otpPlaceholder:"Enter code", verify:"Verify", backToLogin:"Back to sign in",
    dbConnected:"PostgreSQL connected", availableSessions:"Available sessions", bookings:"Bookings", chooseTraining:"Choose a session", futureSessions:"Upcoming sessions with active trainers are shown.",
    refresh:"Refresh ↻", cancelledHistory:"Cancelled bookings remain in your history.", memberTitle:"Your training", receptionTitle:"Reception dashboard",
    memberCopy:"Manage your sessions and keep track of your schedule.", receptionCopy:"Manage all bookings and attendance.", myBookings:"My bookings", allBookings:"All bookings",
    loadingSessions:"Loading schedule…", noSessions:"There are no upcoming sessions right now.", loadingBookings:"Loading bookings…", noBookings:"There are no bookings yet.",
    book:"Book session →", booked:"Slot is occupied", bookedReason:"No places are available — another member has already booked this session.", free:"Available", trainer:"Trainer", booking:"Booking",
    bookingSuccess:"Booking saved successfully.", bookingNumber:"Booking ID", cancel:"Cancel booking", cancelConfirm:"Cancel this booking? The record will remain in history.",
    cancelled:"Booking cancelled. History was preserved.", attended:"Attended", noShow:"No-show", markAttended:"Attended", markNoShow:"No-show", attendanceUpdated:"Attendance updated.",
    statusConfirmed:"Confirmed", statusCancelled:"Cancelled", statusAttended:"Attended", statusNoShow:"No-show", bookingLabel:"Booking", logoutFailed:"Could not end the session."
  }
};
let lang = localStorage.getItem("gym-language") || "ru";
if (!translations[lang]) lang = "ru";
let currentUser = null;
let activeTab = "available";
const t = (key) => translations[lang][key] || translations.ru[key] || key;

function applyLanguage() {
  document.documentElement.lang = lang;
  $("language-select").value = lang;
  document.querySelectorAll("[data-i18n]").forEach(el => { el.textContent = t(el.dataset.i18n); });
  document.querySelectorAll("[data-i18n-html]").forEach(el => { el.innerHTML = t(el.dataset.i18nHtml); });
  document.querySelectorAll("[data-i18n-placeholder]").forEach(el => { el.placeholder = t(el.dataset.i18nPlaceholder); });
  if (currentUser) {
    $("welcome-title").textContent = currentUser.role === "Reception" ? t("receptionTitle") : t("memberTitle");
    $("welcome-copy").textContent = currentUser.role === "Reception" ? t("receptionCopy") : t("memberCopy");
    $("bookings-heading").textContent = currentUser.role === "Reception" ? t("allBookings") : t("myBookings");
    if (currentUser.role === "Member") loadProgress();
    if (activeTab === "available") loadSessions(); else loadBookings();
  }
}
$("language-select").addEventListener("change", e => {
  lang = e.target.value;
  localStorage.setItem("gym-language", lang);
  applyLanguage();
});

async function api(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: { "Content-Type": "application/json", "Accept-Language": lang, ...(options.headers || {}) },
    credentials: "same-origin"
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data.error || "Request failed.");
    error.code = data.code;
    throw error;
  }
  return data;
}
function showNotice(message, bad = false) {
  const el = $("notice");
  el.textContent = message;
  el.classList.toggle("bad", bad);
  el.classList.remove("hidden");
  window.scrollTo({ top: 0, behavior: "smooth" });
}
function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
}
const locale = () => ({kk:"kk-KZ",ru:"ru-RU",en:"en-US"}[lang]);
function dateTime(value) {
  const date = new Date(value);

  if (lang === "kk") {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: "Asia/Almaty",
      year: "numeric",
      month: "numeric",
      day: "numeric"
    }).formatToParts(date);

    const get = type => parts.find(p => p.type === type).value;
    const months = [
      "қаңтар", "ақпан", "наурыз", "сәуір",
      "мамыр", "маусым", "шілде", "тамыз",
      "қыркүйек", "қазан", "қараша", "желтоқсан"
    ];

    return `${get("day")} ${months[Number(get("month")) - 1]} ${get("year")} ж., ${time(value)}`;
  }

  return new Intl.DateTimeFormat(locale(), {
    timeZone: "Asia/Almaty",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

function time(value) {
  return new Intl.DateTimeFormat(locale(), { timeZone:"Asia/Almaty", hour:"2-digit", minute:"2-digit" }).format(new Date(value));
}
function showApp(user) {
  currentUser = user;
  ["login-view","forgot-view","reset-view","twofa-view"].forEach(id => $(id).classList.add("hidden"));
  $("app-view").classList.remove("hidden");
  $("user-area").classList.remove("hidden");
  $("user-label").textContent = user.role === "Reception" ? "Reception" : `Member · ${user.memberId}`;
  $("welcome-title").textContent = user.role === "Reception" ? t("receptionTitle") : t("memberTitle");
  $("welcome-copy").textContent = user.role === "Reception" ? t("receptionCopy") : t("memberCopy");
  $("bookings-heading").textContent = user.role === "Reception" ? t("allBookings") : t("myBookings");
  document.querySelector('[data-tab="available"]').classList.toggle("hidden", user.role === "Reception");
  applyLanguage();
  if (user.role === "Reception") { $("progress-panel").classList.add("hidden"); switchTab("bookings"); }
  else { $("progress-panel").classList.remove("hidden"); loadProgress(); switchTab("available"); }
}
function showTwoFactor() {
  ["login-view","forgot-view","reset-view"].forEach(id => $(id).classList.add("hidden"));
  $("twofa-view").classList.remove("hidden");
  $("twofa-form").reset();
  $("twofa-error").textContent = "";
  $("twofa-form").elements.code.focus();
}
function showLogin() {
  currentUser = null;
  $("notice").classList.add("hidden");
  $("login-error").textContent = "";
  $("app-view").classList.add("hidden");
  $("forgot-view").classList.add("hidden");
  $("reset-view").classList.add("hidden");
  $("twofa-view").classList.add("hidden");
  $("user-area").classList.add("hidden");
  $("login-view").classList.remove("hidden");
}
async function loadSessions() {
  const list = $("sessions-list");
  list.innerHTML = `<div class="empty">${t("loadingSessions")}</div>`;
  try {
    const { sessions } = await api("/api/sessions");
    if (!sessions.length) { list.innerHTML = `<div class="empty">${t("noSessions")}</div>`; return; }
    list.innerHTML = sessions.map(s => {
      const status = s.slot_status || (s.is_booked ? "occupied" : "free");
      const occupied = status === "occupied";
      const unavailable = status === "unavailable";
      if ($("only-available").checked && status !== "free") return "";
      return `<article class="session-card ${occupied ? "occupied" : unavailable ? "unavailable" : ""}">
        <p class="trainer">${escapeHtml(s.trainer)}</p>
        <p class="specialty">${escapeHtml(s.specialization || "")}</p>
        <div class="session-time">${time(s.start_time)} – ${time(s.end_time)}</div>
        <div class="session-date">${dateTime(s.start_time).split(",")[0]}</div>
        <p class="location">⌖ ${escapeHtml(s.location)}</p>
        <div class="session-footer ${occupied ? "session-footer-occupied" : "session-footer-free"}">
          ${occupied
            ? `<button class="button button-booked" type="button" disabled aria-disabled="true">${t("statusOccupied")}</button><p class="slot-reason">${t("bookedReason")}</p><button class="button button-ghost nearest-button" type="button" data-nearest="${escapeHtml(s.session_id)}">${t("findNearest")}</button>`
            : unavailable
              ? `<button class="button button-booked" type="button" disabled>${t("statusUnavailable")}</button>`
              : `<button class="button button-primary" type="button" data-book="${escapeHtml(s.session_id)}">${t("book")}</button>`}
        </div>
      </article>`;
    }).join("");
    if (!list.innerHTML.trim()) list.innerHTML = `<div class="empty">${t("noSessions")}</div>`;
    list.querySelectorAll("[data-book]").forEach(btn => btn.addEventListener("click", () => createBooking(btn.dataset.book, btn)));
    list.querySelectorAll("[data-nearest]").forEach(btn => btn.addEventListener("click", () => findNearest(btn.dataset.nearest, btn)));
  } catch (e) { list.innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`; }
}
async function loadProgress() {
  if (!currentUser || currentUser.role !== "Member") return;
  try {
    const { progress } = await api("/api/progress");
    const attended = Number(progress.attended || 0), target = Number(progress.target || 4);
    $("progress-label").textContent = lang === "en"
      ? `${attended} of ${target} sessions`
      : lang === "kk"
        ? `${attended} / ${target} жаттығу`
        : `${attended} из ${target} тренировок`;
    $("progress-fill").style.width = `${Math.min(100, attended / target * 100)}%`;
    $("progress-fill").setAttribute("aria-valuenow", String(attended));
  } catch (e) { $("progress-label").textContent = e.message; }
}
async function findNearest(sourceSessionId, button) {
  button.disabled = true;
  try {
    const { session } = await api(`/api/sessions/${encodeURIComponent(sourceSessionId)}/nearest`);
    if (!session) { showNotice(t("noNearest"), true); return; }
    const when = `${dateTime(session.start_time)} – ${time(session.end_time)}`;
    if (confirm(`${t("nearestFound")}: ${session.trainer}
${when}
${session.location}

${t("confirmNearest")}`)) {
      await createBooking(session.session_id, button);
    }
  } catch (e) { showNotice(e.message, true); }
  finally { button.disabled = false; }
}

async function createBooking(sessionId, button) {
  button.disabled = true;
  try {
    const { booking, message } = await api("/api/bookings", { method:"POST", body:JSON.stringify({ sessionId }) });
    showNotice(`${message || t("bookingSuccess")} ${t("bookingNumber")}: ${booking.booking_id}`);
    await loadSessions(); await loadBookings();
    switchTab("bookings");
  } catch (e) { showNotice(e.message, true); button.disabled = false; }
}
const statusKeys = { Confirmed:"statusConfirmed", Cancelled:"statusCancelled", Attended:"statusAttended", "No-show":"statusNoShow" };
async function loadBookings() {
  const list = $("bookings-list");
  list.innerHTML = `<div class="empty">${t("loadingBookings")}</div>`;
  try {
    const { bookings } = await api("/api/bookings");
    if (!bookings.length) { list.innerHTML = `<div class="empty">${t("noBookings")}</div>`; return; }
    list.innerHTML = bookings.map(b => `
      <article class="booking-card">
        <div>
          <div class="booking-title">${escapeHtml(b.trainer)} · ${escapeHtml(b.location)}</div>
          <div class="booking-meta">${t("bookingLabel")} ${escapeHtml(b.booking_id)} · ${dateTime(b.start_time)} – ${time(b.end_time)}${currentUser.role === "Reception" ? ` · ${escapeHtml(b.member_name)}` : ""}</div>
          ${currentUser.role === "Member" && b.status === "Confirmed" ? `<div class="booking-actions"><button class="button button-danger" data-cancel="${escapeHtml(b.booking_id)}">${t("cancel")}</button></div>` : ""}
          ${currentUser.role === "Reception" && b.status === "Confirmed" ? `<div class="booking-actions"><button class="button button-ghost" data-attendance="${escapeHtml(b.booking_id)}" data-status="Attended">${t("markAttended")}</button><button class="button button-ghost" data-attendance="${escapeHtml(b.booking_id)}" data-status="No-show">${t("markNoShow")}</button></div>` : ""}
        </div>
        <span class="status ${escapeHtml(b.status)}">${t(statusKeys[b.status])}</span>
      </article>`).join("");
    list.querySelectorAll("[data-cancel]").forEach(btn => btn.addEventListener("click", () => cancelBooking(btn.dataset.cancel)));
    list.querySelectorAll("[data-attendance]").forEach(btn => btn.addEventListener("click", () => updateAttendance(btn.dataset.attendance, btn.dataset.status)));
  } catch (e) { list.innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`; }
}
async function cancelBooking(id) {
  if (!confirm(t("cancelConfirm"))) return;
  try {
    const { message } = await api(`/api/bookings/${encodeURIComponent(id)}/cancel`, { method:"POST", body:"{}" });
    showNotice(message || t("cancelled")); await loadBookings(); await loadSessions();
  } catch (e) { showNotice(e.message, true); }
}
async function updateAttendance(id, status) {
  try {
    const { message } = await api(`/api/bookings/${encodeURIComponent(id)}/attendance`, { method:"POST", body:JSON.stringify({ status }) });
    showNotice(message || t("attendanceUpdated")); await loadBookings(); await loadProgress();
  } catch (e) { showNotice(e.message, true); }
}
function switchTab(tab) {
  activeTab = tab;
  $("available-panel").classList.toggle("hidden", tab !== "available");
  $("bookings-panel").classList.toggle("hidden", tab !== "bookings");
  document.querySelectorAll(".tab").forEach(b => b.classList.toggle("active", b.dataset.tab === tab));
  if (tab === "available") loadSessions(); else loadBookings();
}
function showRecovery(view) {
  ["login-view","forgot-view","reset-view","twofa-view","app-view"].forEach(id => $(id).classList.add("hidden"));
  $(view).classList.remove("hidden");
  $("user-area").classList.add("hidden");
}
$("forgot-password-link").addEventListener("click", () => { showRecovery("forgot-view"); $("forgot-message").textContent = ""; });
$("forgot-back").addEventListener("click", () => showLogin());
$("forgot-form").addEventListener("submit", async e => {
  e.preventDefault(); const email = new FormData(e.currentTarget).get("email");
  const out = $("forgot-message"); out.textContent = "";
  try { const result = await api("/api/password/forgot", { method:"POST", body:JSON.stringify({ email }) }); out.textContent = result.message || t("resetLinkSent"); }
  catch (err) { out.textContent = err.message; out.classList.add("error-text"); }
});
$("reset-form").addEventListener("submit", async e => {
  e.preventDefault(); const data = new FormData(e.currentTarget);
  const password = data.get("password"), confirmPassword = data.get("confirmPassword");
  const out = $("reset-message"); out.textContent = "";
  if (password !== confirmPassword) { out.textContent = t("passwordMismatch"); return; }
  const token = new URLSearchParams(location.hash.slice(1))
    .get("reset-password");
  try { const result = await api("/api/password/reset", { method:"POST", body:JSON.stringify({ token, password }) }); out.textContent = result.message || "OK"; }
  catch (err) { out.textContent = err.message; out.classList.add("error-text"); }
});

$("login-form").addEventListener("submit", async e => {
  e.preventDefault();
  const loginForm = e.currentTarget;
  $("login-error").textContent = "";
  const form = new FormData(loginForm);
  try {
    const result = await api("/api/login", { method:"POST", body:JSON.stringify({ username:form.get("username"), password:form.get("password") }) });
    loginForm.reset();
    if (result.twoFactorRequired) showTwoFactor();
  } catch (err) { $("login-error").textContent = err.message; }
});
$("twofa-form").addEventListener("submit", async e => {
  e.preventDefault();
  $("twofa-error").textContent = "";
  const codeForm = e.currentTarget;
  const code = new FormData(codeForm).get("code");
  try {
    const result = await api("/api/login/2fa", { method:"POST", body:JSON.stringify({ code }) });
    codeForm.reset();
    showApp(result.user);
  } catch (err) {
    if (["2FA_EXPIRED", "2FA_LOCKED", "2FA_NOT_ENROLLED"].includes(err.code)) {
      showLogin();
      $("login-error").textContent = err.message;
    } else {
      $("twofa-error").textContent = err.message;
    }
  }
});
$("back-to-login").addEventListener("click", async () => {
  try {
    await api("/api/logout", { method: "POST", body: "{}" });
    $("twofa-form").reset();
    showLogin();
  } catch (err) {
    $("twofa-error").textContent = err.message;
  }
});
$("logout-btn").addEventListener("click", async () => { try { await api("/api/logout", { method:"POST", body:"{}" }); } finally { showLogin(); } });
$("refresh-sessions").addEventListener("click", loadSessions);
$("only-available").addEventListener("change", loadSessions);
$("refresh-bookings").addEventListener("click", loadBookings);
document.querySelectorAll(".tab").forEach(b => b.addEventListener("click", () => switchTab(b.dataset.tab)));
(async function init() {
  applyLanguage();
  if (new URLSearchParams(location.hash.slice(1)).has("reset-password")) {
    showRecovery("reset-view");
    return;
  }
  try { const { user, pending } = await api("/api/me"); if (user) showApp(user); else if (pending) showTwoFactor(); }
  catch (_) { showLogin(); }
})();
