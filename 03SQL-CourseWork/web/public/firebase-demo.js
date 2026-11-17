import { signInWithGoogle, signOutGoogle } from "./firebase-auth.js";
const config = window.COURSEWORK_CONFIG?.firebaseConfig;
const login = document.getElementById("login");
const logout = document.getElementById("logout");
const status = document.getElementById("status");
const identity = document.getElementById("identity");
document.getElementById("project").textContent = `Проект: ${config?.projectId || "не настроен"}`;
login.disabled = !config?.projectId;
login.addEventListener("click", async () => {
  login.disabled = true;
  status.textContent = "Открываем Google…";
  try {
    const result = await signInWithGoogle(config);
    identity.replaceChildren();
    for (const [label, value] of [["Firebase UID", result.user.uid], ["Email", result.user.email || "не указан"]]) {
      const term = document.createElement("dt"); term.textContent = label;
      const detail = document.createElement("dd"); detail.textContent = value;
      identity.append(term, detail);
    }
    status.textContent = "Firebase подтвердил вход. Это не подтверждает доступность SQL API.";
    logout.disabled = false;
  } catch (error) {
    status.textContent = `Вход не выполнен: ${error.code || "ошибка сети"}. Проверьте Google provider и разрешённый домен в Firebase Console.`;
    login.disabled = false;
  }
});
logout.addEventListener("click", async () => {
  logout.disabled = true;
  try { await signOutGoogle(); identity.replaceChildren(); status.textContent = "Вы вышли."; login.disabled = false; }
  catch { status.textContent = "Выход не подтверждён. Перезагрузите страницу, чтобы очистить сессию из памяти."; logout.disabled = false; }
});
