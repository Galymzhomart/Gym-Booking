// reset_messages.js (Ruslan). Texts of the password-recovery answers. The interface shows them by `code`.
const resetMessages = {
  kk: {
    resetSent: "Егер бұл email жүйеде тіркелген болса, құпиясөзді қалпына келтіру сілтемесі жіберілді.",
    resetEmailFormat: "Дұрыс email енгізіңіз.",
    resetRateLimited: "Сұрау тым көп. Кейінірек қайталап көріңіз.",
    resetInvalid: "Сілтеме жарамсыз. Жаңа сілтеме сұраңыз.",
    resetExpired: "Сілтеменің мерзімі аяқталды. Жаңа сілтеме сұраңыз.",
    resetUsed: "Бұл сілтеме бұрын қолданылған. Қажет болса, жаңа сілтеме сұраңыз.",
    passwordWeak: "Құпиясөз кемінде 8 таңбадан тұруы, әріп пен цифр қамтуы керек.",
    passwordSame: "Жаңа құпиясөз ескісінен өзгеше болуы керек.",
    passwordMismatch: "Құпиясөздер сәйкес келмейді.",
    passwordChanged: "Құпиясөз өзгертілді. Жаңа құпиясөзбен кіріңіз, содан кейін растау кодын енгізіңіз."
  },
  ru: {
    resetSent: "Если этот email зарегистрирован, мы отправили ссылку для восстановления пароля.",
    resetEmailFormat: "Введите корректный email.",
    resetRateLimited: "Слишком много запросов. Попробуйте позже.",
    resetInvalid: "Ссылка недействительна. Запросите новую.",
    resetExpired: "Срок действия ссылки истёк. Запросите новую.",
    resetUsed: "Эта ссылка уже использована. При необходимости запросите новую.",
    passwordWeak: "Пароль должен содержать не менее 8 символов, буквы и цифры.",
    passwordSame: "Новый пароль должен отличаться от старого.",
    passwordMismatch: "Пароли не совпадают.",
    passwordChanged: "Пароль изменён. Войдите с новым паролем и введите код подтверждения."
  },
  en: {
    resetSent: "If this e-mail is registered, we sent a password recovery link.",
    resetEmailFormat: "Enter a valid e-mail address.",
    resetRateLimited: "Too many requests. Try again later.",
    resetInvalid: "The link is not valid. Request a new one.",
    resetExpired: "The link has expired. Request a new one.",
    resetUsed: "This link has already been used. Request a new one if needed.",
    passwordWeak: "The password must have at least 8 characters, including letters and digits.",
    passwordSame: "The new password must differ from the old one.",
    passwordMismatch: "The passwords do not match.",
    passwordChanged: "Password changed. Sign in with the new password, then enter the verification code."
  }
};
module.exports = { resetMessages };
