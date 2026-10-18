import { ApiClient, ApiError } from "./api.js";

const $ = (id) => document.getElementById(id);
const ID_PATTERN = /^[1-9][0-9]{0,18}$/;
const MAX_FILE_BYTES = 10 * 1024 * 1024;
const views = ["feed", "communities", "documents", "assistant"];
const state = {
  session: null,
  firebaseSignIn: false,
  view: "feed",
  communities: [],
  communityCursor: null,
  selectedCommunityId: null,
  posts: [],
  postCursor: null,
  documents: [],
  documentCursor: null,
  documentCommunityId: null,
  ragQueryId: null,
  ragPollCount: 0,
  ragPollTimer: null,
  documentPollTimer: null,
  documentCheckId: null,
  toastTimer: null,
  downloadController: null,
  dialogVersion: 0
};

let api;
try {
  api = new ApiClient(window.COURSEWORK_CONFIG?.apiBaseUrl || "/api", clearSession);
} catch {
  api = new ApiClient("/api", clearSession);
}
$("api-base").value = api.baseUrl;
if (window.COURSEWORK_CONFIG?.backendReady === false) {
  $("deployment-notice").textContent = "Публичный API пока не подключён. Сайт показывает интерфейс курсовой; для работы функций укажите адрес доступного HTTPS API.";
  $("deployment-notice").hidden = false;
}
if (window.COURSEWORK_CONFIG?.firebaseConfig?.apiKey && window.COURSEWORK_CONFIG?.firebaseConfig?.projectId && window.COURSEWORK_CONFIG?.firebaseConfig?.authDomain && window.COURSEWORK_CONFIG?.firebaseConfig?.appId) {
  $("firebase-signin").hidden = false;
  $("auth-alternative").hidden = false;
}

function element(tag, className = "", text = "") {
  const item = document.createElement(tag);
  if (className) item.className = className;
  if (text !== "") item.textContent = String(text);
  return item;
}

function action(label, className, handler) {
  const item = element("button", className, label);
  item.type = "button";
  item.addEventListener("click", (event) => {
    try {
      const result = handler(event);
      if (result && typeof result.catch === "function") result.catch((error) => report(error));
    } catch (error) { report(error); }
  });
  return item;
}

function append(parent, ...children) {
  parent.append(...children.filter(Boolean));
  return parent;
}

function textBlock(message, kind = "empty") {
  return element("p", kind === "error" ? "inline-error" : "empty-state", message);
}

function safeId(value) {
  const id = String(value ?? "");
  if (!ID_PATTERN.test(id)) throw new ApiError("Некорректный идентификатор.", 0, "INVALID_ID");
  return id;
}

function encodedQuery(values) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value !== null && value !== undefined && value !== "") params.set(key, String(value));
  }
  return params.toString();
}

function readableTime(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : new Intl.DateTimeFormat("ru-RU", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function report(error, target) {
  if (error?.name === "AbortError") return;
  const message = error instanceof ApiError ? error.message : "Не удалось выполнить действие. Попробуйте ещё раз.";
  if (target) target.replaceChildren(textBlock(message, "error"));
  toast(message, true);
}

function toast(message, isError = false) {
  const item = $("toast");
  item.textContent = message;
  item.classList.toggle("is-error", isError);
  item.hidden = false;
  clearTimeout(state.toastTimer);
  state.toastTimer = setTimeout(() => { item.hidden = true; }, 6000);
}

function setBusy(form, busy) {
  for (const control of form.elements) control.disabled = busy;
  form.classList.toggle("is-busy", busy);
}

function requireSession() {
  if (!state.session) throw new ApiError("Сначала подключите сессию.", 401, "NO_SESSION");
  if (!state.firebaseSignIn && new Date(state.session.expiresAt).getTime() <= Date.now()) {
    clearSession();
    throw new ApiError("Сессия завершилась. Подключитесь снова.", 401, "SESSION_EXPIRED");
  }
}

function clearSession() {
  api.cancelPending();
  state.downloadController?.abort();
  state.downloadController = null;
  state.dialogVersion += 1;
  state.session = null;
  state.firebaseSignIn = false;
  api.setTokenProvider(null);
  api.setAccessToken(null);
  clearTimeout(state.ragPollTimer);
  clearTimeout(state.documentPollTimer);
  state.ragQueryId = null;
  state.communities = [];
  state.communityCursor = null;
  state.selectedCommunityId = null;
  state.posts = [];
  state.postCursor = null;
  state.documents = [];
  state.documentCursor = null;
  state.documentCommunityId = null;
  state.documentCheckId = null;
  $("workspace").hidden = true;
  $("connection-panel").hidden = false;
  $("current-user").hidden = true;
  $("sign-out").hidden = true;
  $("connection-status").textContent = "Нет сессии";
  $("connection-status").classList.remove("is-online");
  $("identity-token").value = "";
  $("rag-form").reset();
  $("document-text-form").reset();
  $("document-file-form").reset();
  $("document-lookup-form").reset();
  $("feed-list").replaceChildren();
  $("community-list").replaceChildren();
  $("community-detail").replaceChildren();
  $("document-list").replaceChildren();
  $("document-status").replaceChildren();
  $("rag-result").replaceChildren();
  if ($("content-dialog").open) $("content-dialog").close();
}

async function connect(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const tokenField = $("identity-token");
  const identityToken = tokenField.value.trim();
  tokenField.value = "";
  $("connection-feedback").textContent = "Подключаемся к серверу…";
  setBusy(form, true);
  try {
    api.setBaseUrl($("api-base").value);
    await activateToken(identityToken);
  } catch (error) {
    api.setAccessToken(null);
    const message = error.status === 404
      ? "Маршрут проверки сессии не найден. Проверьте backend и адрес API."
      : (error.message || "Не удалось подключиться.");
    $("connection-feedback").textContent = message;
    toast(message, true);
  } finally {
    setBusy(form, false);
  }
}

async function signOut() {
  if (state.firebaseSignIn) {
    try {
      const firebase = await import("./firebase-auth.js");
      await firebase.signOutGoogle();
    } catch { /* Local sign-out still clears the token. */ }
  }
  clearSession();
  toast("Токен удалён из памяти этой вкладки.");
}

async function activateToken(token, tokenProvider = null) {
  const expiresAt = firebaseTokenExpiry(token);
  if (!expiresAt || new Date(expiresAt).getTime() <= Date.now()) {
    throw new ApiError("Нужен действующий Firebase ID token.", 0, "INVALID_TOKEN");
  }
  api.setAccessToken(token);
  api.setTokenProvider(tokenProvider);
  const identity = await api.request("/v1/auth/sessions/current");
  const user = identity?.user || identity;
  if (!user?.userId) throw new ApiError("Сервер не вернул профиль текущего пользователя.", 0, "BAD_IDENTITY");
  state.session = { user, expiresAt };
  state.firebaseSignIn = Boolean(tokenProvider);
  $("connection-panel").hidden = true;
  $("workspace").hidden = false;
  $("current-user").textContent = user.displayName || `Пользователь #${user.userId}`;
  $("current-user").hidden = false;
  $("sign-out").hidden = false;
  $("connection-status").textContent = "Подключено";
  $("connection-status").classList.add("is-online");
  $("connection-feedback").textContent = "";
  showView("feed");
  await Promise.allSettled([
    loadCommunities(true).catch((error) => report(error, $("community-list"))),
    loadFeed()
  ]);
}

async function firebaseSignIn() {
  const button = $("firebase-signin");
  button.disabled = true;
  $("connection-feedback").textContent = "Открываем окно входа…";
  try {
    api.setBaseUrl($("api-base").value);
    const firebase = await import("./firebase-auth.js");
    const credentials = await firebase.signInWithGoogle(window.COURSEWORK_CONFIG.firebaseConfig);
    await activateToken(credentials.token, credentials.tokenProvider);
  } catch (error) {
    api.setTokenProvider(null);
    api.setAccessToken(null);
    const message = error?.code === "auth/popup-closed-by-user" ? "Окно входа закрыто."
      : error?.status === 404 ? "Маршрут проверки сессии не найден. Проверьте backend и адрес API."
        : (error.message || "Не удалось войти через Google.");
    $("connection-feedback").textContent = message;
    toast(message, true);
  } finally { button.disabled = false; }
}

function firebaseTokenExpiry(token) {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=")));
    return Number.isSafeInteger(payload.exp) ? new Date(payload.exp * 1000).toISOString() : null;
  } catch { return null; }
}

function showView(name) {
  if (!views.includes(name)) return;
  state.view = name;
  for (const view of views) $("view-" + view).hidden = view !== name;
  for (const button of document.querySelectorAll("[data-view]")) {
    const active = button.dataset.view === name;
    button.classList.toggle("is-active", active);
    if (active) button.setAttribute("aria-current", "page"); else button.removeAttribute("aria-current");
  }
  if (name === "documents") {
    syncCommunitySelectors();
    if (state.documentCommunityId) loadDocuments(true).catch((error) => report(error, $("document-list")));
  }
  window.scrollTo({ top: $("workspace").offsetTop - 80, behavior: "smooth" });
}

async function loadCommunities(reset = false) {
  requireSession();
  const session = state.session;
  if (reset) {
    state.communityCursor = null;
    state.communities = [];
    $("community-list").replaceChildren(textBlock("Загружаем сообщества…"));
  }
  const query = encodedQuery({ limit: 20, cursor: state.communityCursor });
  const page = await api.request(`/v1/communities?${query}`);
  if (state.session !== session) return;
  if (!Array.isArray(page?.items)) throw new ApiError("Неверный формат списка сообществ.", 0, "BAD_RESPONSE");
  state.communities.push(...page.items);
  state.communityCursor = page.nextCursor || null;
  renderCommunities();
  syncCommunitySelectors();
  if (!state.selectedCommunityId && state.communities.length) await selectCommunity(state.communities[0].communityId);
}

function renderCommunities() {
  const container = $("community-list");
  container.replaceChildren();
  if (!state.communities.length) container.append(textBlock("Доступных сообществ пока нет. Создайте первое."));
  for (const community of state.communities) {
    const selected = String(community.communityId) === state.selectedCommunityId;
    const card = action("", `community-choice${selected ? " is-selected" : ""}`, () => selectCommunity(community.communityId));
    append(card, element("strong", "", community.name), element("small", "", community.visibility === "PRIVATE" ? "Закрытое · доступно вам" : "Открытое"));
    container.append(card);
  }
  $("more-communities").hidden = !state.communityCursor;
}

function syncCommunitySelectors() {
  const documentSelect = $("document-community");
  const ragSelect = $("rag-community");
  const currentDocument = state.documentCommunityId || documentSelect.value;
  const currentRag = ragSelect.value;
  documentSelect.replaceChildren();
  ragSelect.replaceChildren(new Option("Во всех доступных сообществах", ""));
  if (!state.communities.length) documentSelect.append(new Option("Нет доступных сообществ", ""));
  for (const community of state.communities) {
    documentSelect.append(new Option(community.name, String(community.communityId)));
    ragSelect.append(new Option(community.name, String(community.communityId)));
  }
  documentSelect.value = state.communities.some((item) => String(item.communityId) === currentDocument)
    ? currentDocument : (state.selectedCommunityId || documentSelect.options[0]?.value || "");
  state.documentCommunityId = documentSelect.value || null;
  ragSelect.value = state.communities.some((item) => String(item.communityId) === currentRag) ? currentRag : "";
  updateDocumentWriteState();
}

function updateDocumentWriteState() {
  const community = state.communities.find((item) => String(item.communityId) === state.documentCommunityId);
  const canWrite = community && (community.membershipStatus === "ACTIVE" || String(community.ownerUserId) === String(state.session?.user?.userId));
  $("document-write-hint").hidden = Boolean(canWrite);
  for (const formId of ["document-text-form", "document-file-form"]) {
    for (const control of $(formId).elements) control.disabled = !canWrite;
  }
}

async function selectCommunity(rawId) {
  const id = safeId(rawId);
  const session = state.session;
  state.selectedCommunityId = id;
  renderCommunities();
  const detail = $("community-detail");
  detail.replaceChildren(textBlock("Открываем сообщество…"));
  try {
    const community = await api.request(`/v1/communities/${id}`);
    if (state.selectedCommunityId !== id || state.session !== session) return;
    renderCommunityDetail(community);
    await loadPosts(true);
  } catch (error) {
    if (state.selectedCommunityId === id) report(error, detail);
  }
}

function renderCommunityDetail(community) {
  const detail = $("community-detail");
  detail.replaceChildren();
  const head = element("div", "community-head");
  const info = element("div");
  append(info, element("p", "eyebrow", community.visibility === "PRIVATE" ? "ЗАКРЫТОЕ СООБЩЕСТВО" : "ОТКРЫТОЕ СООБЩЕСТВО"), element("h3", "", community.name), element("p", "muted", community.description || "Описание пока не добавлено."));
  const meta = element("div", "community-meta");
  append(meta, element("span", "outline-tag", `#${community.slug}`), element("span", "outline-tag", membershipText(community.membershipStatus)));
  info.append(meta);
  head.append(info);
  if (["NONE", "LEFT", "REJECTED"].includes(community.membershipStatus)) head.append(action("Вступить", "button button-primary", () => joinCommunity(community.communityId)));
  if (community.membershipStatus === "PENDING") head.append(element("span", "pending-label", "Заявка ожидает решения"));
  detail.append(head);
  const canWrite = community.membershipStatus === "ACTIVE" || String(community.ownerUserId) === String(state.session?.user?.userId);
  if (canWrite) {
    const form = element("form", "post-compose");
    const label = element("label", "field");
    label.setAttribute("for", "new-post-body");
    append(label, element("span", "", "Новая публикация"));
    const input = element("textarea");
    input.id = "new-post-body";
    input.name = "body";
    input.rows = 3;
    input.required = true;
    input.placeholder = "Поделитесь идеей или обновлением…";
    label.append(input);
    append(form, label, action("Опубликовать ↗", "button button-primary", () => publishPost(form, community.communityId)));
    detail.append(form);
  } else {
    detail.append(element("p", "hint", "Публиковать могут активные участники сообщества."));
  }
  const heading = element("div", "subheading");
  append(heading, element("h4", "", "Публикации"), action("Обновить", "text-button", () => loadPosts(true).catch((error) => report(error, $("post-list")))));
  const list = element("div", "card-list", "");
  list.id = "post-list";
  const more = action("Показать ещё", "button button-quiet", () => loadPosts(false).catch((error) => report(error, list)));
  more.id = "more-posts";
  more.hidden = true;
  append(detail, heading, list, more);
}

function membershipText(status) {
  return ({ ACTIVE: "Участник", PENDING: "Заявка ожидает", BLOCKED: "Доступ закрыт", NONE: "Не участник", LEFT: "Не участник", REJECTED: "Заявка отклонена", BANNED: "Доступ закрыт" })[status] || "Статус неизвестен";
}

async function joinCommunity(rawId) {
  try {
    const id = safeId(rawId);
    const membership = await api.request(`/v1/communities/${id}/memberships`, { method: "POST" });
    toast(membership?.status === "PENDING" ? "Заявка отправлена. Ожидайте решения." : "Вы вступили в сообщество.");
    await loadCommunities(true);
    if (membership?.status === "ACTIVE") await selectCommunity(id);
  } catch (error) { report(error); }
}

async function publishPost(form, rawId) {
  const body = form.elements.body.value.trim();
  if (!body) return;
  setBusy(form, true);
  try {
    await api.request(`/v1/communities/${safeId(rawId)}/posts`, { method: "POST", json: { body } });
    form.reset();
    toast("Публикация создана. Поисковый индекс обновится позже.");
    await loadPosts(true);
  } catch (error) { report(error); }
  finally { setBusy(form, false); }
}

async function loadPosts(reset = false) {
  requireSession();
  const session = state.session;
  const id = safeId(state.selectedCommunityId);
  const list = $("post-list");
  if (!list) return;
  if (reset) {
    state.posts = [];
    state.postCursor = null;
    list.replaceChildren(textBlock("Загружаем публикации…"));
  }
  const query = encodedQuery({ limit: 20, cursor: state.postCursor });
  const page = await api.request(`/v1/communities/${id}/posts?${query}`);
  if (state.selectedCommunityId !== id || state.session !== session) return;
  if (!Array.isArray(page?.items)) throw new ApiError("Неверный формат публикаций.", 0, "BAD_RESPONSE");
  state.posts.push(...page.items);
  state.postCursor = page.nextCursor || null;
  list.replaceChildren();
  if (!state.posts.length) list.append(textBlock("Публикаций пока нет."));
  for (const post of state.posts) list.append(renderPost(post));
  $("more-posts").hidden = !state.postCursor;
}

function renderPost(post) {
  const card = element("article", "content-card");
  const header = element("div", "card-topline");
  append(header, element("span", "card-kicker", `ПОСТ · #${post.contentId}`), element("time", "", readableTime(post.publishedAt)));
  const body = element("p", "post-body", post.body);
  const footer = element("div", "card-actions");
  append(footer, element("span", "card-author", `Автор #${post.authorUserId}`));
  footer.append(action("Комментарии", "text-button", () => toggleComments(card, post.contentId)));
  footer.append(action("Полезно", "text-button", () => react(post.contentId)));
  if (String(post.authorUserId) === String(state.session?.user?.userId)) {
    footer.append(action("Изменить", "text-button", () => openEditor("POST", post.contentId, post.body)));
    footer.append(action("Скрыть", "text-button danger", () => hideOwnContent("POST", post.contentId)));
  }
  append(card, header, body, footer);
  const comments = element("div", "comments-area");
  comments.hidden = true;
  card.append(comments);
  return card;
}

async function toggleComments(card, postId) {
  const area = card.querySelector(".comments-area");
  area.hidden = !area.hidden;
  if (area.hidden) return;
  area.replaceChildren(textBlock("Загружаем комментарии…"));
  try {
    const page = await api.request(`/v1/posts/${safeId(postId)}/comments?limit=50`);
    if (!Array.isArray(page?.items)) throw new ApiError("Неверный формат комментариев.", 0, "BAD_RESPONSE");
    area.replaceChildren();
    if (!page.items.length) area.append(textBlock("Комментариев пока нет."));
    for (const comment of page.items) area.append(renderComment(comment));
    if (page.nextCursor) {
      let cursor = page.nextCursor;
      const more = action("Показать ещё комментарии", "text-button", async () => {
        more.disabled = true;
        try {
          const next = await api.request(`/v1/posts/${safeId(postId)}/comments?${encodedQuery({ limit: 50, cursor })}`);
          if (!Array.isArray(next?.items)) throw new ApiError("Неверный формат комментариев.", 0, "BAD_RESPONSE");
          for (const comment of next.items) area.insertBefore(renderComment(comment), more);
          cursor = next.nextCursor || null;
          if (!cursor) more.remove();
        } catch (error) { report(error); }
        finally { more.disabled = false; }
      });
      area.append(more);
    }
    const form = element("form", "comment-form");
    const label = element("label", "field");
    const input = element("textarea");
    input.name = "body";
    input.rows = 2;
    input.required = true;
    input.placeholder = "Добавить комментарий";
    append(label, element("span", "sr-only", "Текст комментария"), input);
    append(form, label, action("Отправить", "button button-outline", async () => {
      const body = input.value.trim();
      if (!body) return;
      setBusy(form, true);
      try {
        await api.request(`/v1/posts/${safeId(postId)}/comments`, { method: "POST", json: { body } });
        area.hidden = true;
        await toggleComments(card, postId);
        toast("Комментарий опубликован.");
      } catch (error) { report(error); }
      finally { setBusy(form, false); }
    }));
    area.append(form);
  } catch (error) { report(error, area); }
}

function renderComment(comment) {
  const item = element("div", "comment-card");
  const top = element("div", "card-topline");
  append(top, element("span", "card-author", `Автор #${comment.authorUserId}`), element("time", "", readableTime(comment.publishedAt)));
  append(item, top, element("p", "post-body", comment.body));
  const actions = element("div", "card-actions");
  actions.append(action("Полезно", "text-button", () => react(comment.contentId)));
  if (String(comment.authorUserId) === String(state.session?.user?.userId)) {
    actions.append(action("Изменить", "text-button", () => openEditor("COMMENT", comment.contentId, comment.body)));
    actions.append(action("Скрыть", "text-button danger", () => hideOwnContent("COMMENT", comment.contentId)));
  }
  item.append(actions);
  return item;
}

async function react(rawId) {
  try {
    await api.request(`/v1/content/${safeId(rawId)}/reaction`, { method: "PUT", json: { type: "HELPFUL" } });
    toast("Реакция сохранена.");
  } catch (error) { report(error); }
}

function openEditor(kind, rawId, currentBody) {
  state.dialogVersion += 1;
  const dialog = $("content-dialog");
  $("dialog-title").textContent = kind === "POST" ? "Изменить публикацию" : "Изменить комментарий";
  const container = $("dialog-content");
  const form = element("form", "stack-form");
  const label = element("label", "field");
  const input = element("textarea");
  input.rows = 7;
  input.required = true;
  input.value = currentBody;
  append(label, element("span", "", "Новая редакция"), input);
  const submit = element("button", "button button-primary", "Сохранить редакцию");
  submit.type = "submit";
  append(form, label, submit);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const body = input.value.trim();
    if (!body) return;
    setBusy(form, true);
    try {
      const path = kind === "POST" ? `/v1/posts/${safeId(rawId)}` : `/v1/comments/${safeId(rawId)}`;
      await api.request(path, { method: "PATCH", json: { body } });
      dialog.close();
      toast("Редакция сохранена.");
      await loadPosts(true);
    } catch (error) { report(error); }
    finally { setBusy(form, false); }
  });
  container.replaceChildren(form);
  dialog.showModal();
}

async function hideOwnContent(kind, rawId) {
  if (!window.confirm("Скрыть материал? Он исчезнет из ленты и новых ответов помощника.")) return;
  try {
    const path = kind === "POST" ? `/v1/posts/${safeId(rawId)}` : `/v1/comments/${safeId(rawId)}`;
    await api.request(path, { method: "DELETE" });
    toast("Материал скрыт.");
    await loadPosts(true);
  } catch (error) { report(error); }
}

async function createCommunity(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const data = new FormData(form);
  setBusy(form, true);
  try {
    const payload = {
      slug: String(data.get("slug")).trim(),
      name: String(data.get("name")).trim(),
      description: String(data.get("description")).trim(),
      visibility: data.get("visibility")
    };
    const community = await api.request("/v1/communities", { method: "POST", json: payload });
    form.reset();
    toast("Сообщество создано.");
    await loadCommunities(true);
    await selectCommunity(community.communityId);
  } catch (error) { report(error); }
  finally { setBusy(form, false); }
}

async function loadFeed() {
  requireSession();
  const session = state.session;
  const list = $("feed-list");
  list.replaceChildren(textBlock("Подбираем доступные материалы…"));
  try {
    const response = await api.request("/v1/feed?limit=20");
    if (state.session !== session) return;
    if (!Array.isArray(response?.items)) throw new ApiError("Неверный формат ленты.", 0, "BAD_RESPONSE");
    if (!response.items.length) {
      list.replaceChildren(textBlock("Пока нет рекомендаций. Вступите в сообщество или вернитесь позже."));
      return;
    }
    const details = await Promise.allSettled(response.items.map(async (item) => {
      const path = item.kind === "POST" ? `/v1/posts/${safeId(item.contentId)}` : `/v1/documents/${safeId(item.contentId)}`;
      const content = await api.request(path);
      return { item, content };
    }));
    if (state.session !== session) return;
    list.replaceChildren();
    for (const result of details) {
      if (result.status === "fulfilled") list.append(renderFeedItem(result.value.item, result.value.content));
    }
    if (!list.children.length) list.append(textBlock("Материалы ленты стали недоступны. Обновите выдачу."));
  } catch (error) { report(error, list); }
}

function renderFeedItem(item, content) {
  const card = element("article", "content-card feed-card");
  const top = element("div", "card-topline");
  append(top, element("span", "card-kicker", item.kind === "POST" ? "ПУБЛИКАЦИЯ" : "ДОКУМЕНТ"), element("span", "rank-label", `№ ${item.rank}`));
  const title = element("h3", "", item.kind === "POST" ? `Публикация #${item.contentId}` : content.title);
  const snippet = item.kind === "POST" ? content.body : `${content.mimeType || "Документ"} · версия ${content.versionNo || "?"}`;
  const body = element("p", "post-body feed-preview", snippet);
  const reason = element("div", "reason-line");
  append(reason, element("span", "reason-dot", "↗"), element("span", "", item.reasonText));
  const footer = element("div", "card-actions");
  append(footer, element("span", "card-author", `Сообщество #${item.communityId}`), action("Открыть", "text-button", () => openSource(item.kind, item.contentId)));
  append(card, top, title, body, reason, footer);
  return card;
}

async function loadDocuments(reset = false) {
  requireSession();
  const session = state.session;
  const communityId = state.documentCommunityId;
  const list = $("document-list");
  if (!communityId) {
    list.replaceChildren(textBlock("Выберите сообщество, чтобы увидеть документы."));
    return;
  }
  if (reset) {
    state.documents = [];
    state.documentCursor = null;
    list.replaceChildren(textBlock("Загружаем документы…"));
  }
  const query = encodedQuery({ limit: 20, cursor: state.documentCursor });
  const page = await api.request(`/v1/communities/${safeId(communityId)}/documents?${query}`);
  if (state.documentCommunityId !== communityId || state.session !== session) return;
  if (!Array.isArray(page?.items)) throw new ApiError("Неверный формат документов.", 0, "BAD_RESPONSE");
  state.documents.push(...page.items);
  state.documentCursor = page.nextCursor || null;
  list.replaceChildren();
  if (!state.documents.length) list.append(textBlock("Готовых документов пока нет."));
  for (const documentItem of state.documents) list.append(renderDocument(documentItem));
  $("more-documents").hidden = !state.documentCursor;
}

function renderDocument(documentItem) {
  const card = element("article", "document-card");
  append(card, element("p", "card-kicker", `ДОКУМЕНТ · #${documentItem.contentId}`), element("h4", "", documentItem.title), element("p", "muted", `Версия ${documentItem.versionNo} · ${documentItem.processingStatus}`));
  card.append(action("Открыть", "text-button", () => openSource("DOCUMENT", documentItem.contentId)));
  return card;
}

async function submitDocument(event, mode) {
  event.preventDefault();
  const form = event.currentTarget;
  const data = new FormData(form);
  setBusy(form, true);
  try {
    const communityId = safeId(state.documentCommunityId);
    const title = String(data.get("title") || "").trim();
    let options;
    if (mode === "text") {
      const text = String(data.get("text") || "").trim();
      if (text.length * 2 > MAX_FILE_BYTES) throw new ApiError("Текст превышает 10 МиБ в UTF-16.", 0, "TOO_LARGE");
      options = { method: "POST", json: { title, text } };
    } else {
      const file = $("document-file").files[0];
      if (!file) throw new ApiError("Выберите PDF или DOCX.", 0, "FILE_REQUIRED");
      if (file.size > MAX_FILE_BYTES) throw new ApiError("Файл превышает 10 МиБ.", 0, "TOO_LARGE");
      if (!/\.(pdf|docx)$/i.test(file.name)) throw new ApiError("Поддерживаются PDF и DOCX.", 0, "BAD_FILE_TYPE");
      const payload = new FormData();
      payload.set("title", title);
      payload.set("file", file);
      options = { method: "POST", form: payload };
    }
    const result = await api.request(`/v1/communities/${communityId}/documents`, options);
    form.reset();
    $("document-lookup-id").value = String(result.contentId);
    toast("Документ принят в обработку.");
    await checkDocument(result.contentId, true);
  } catch (error) { report(error); }
  finally { setBusy(form, false); updateDocumentWriteState(); }
}

async function checkDocument(rawId, schedule = false) {
  clearTimeout(state.documentPollTimer);
  const session = state.session;
  const target = $("document-status");
  target.replaceChildren(textBlock("Проверяем состояние документа…"));
  try {
    const id = safeId(rawId);
    state.documentCheckId = id;
    const documentItem = await api.request(`/v1/documents/${id}`);
    if (state.session !== session || state.documentCheckId !== id) return;
    target.replaceChildren(renderDocumentStatus(documentItem));
    if (documentItem.processingStatus === "READY") await loadDocuments(true);
    else if (schedule && documentItem.processingStatus === "PROCESSING") {
      state.documentPollTimer = setTimeout(() => checkDocument(id, true), 5000);
    }
  } catch (error) { report(error, target); }
}

function renderDocumentStatus(item) {
  const card = element("article", "status-card");
  append(card, element("p", "card-kicker", `ДОКУМЕНТ #${item.contentId}`), element("h4", "", item.title));
  const label = ({ PROCESSING: "Обрабатывается", READY: "Готов к чтению и поиску", FAILED: "Обработка не удалась" })[item.processingStatus] || item.processingStatus;
  card.append(element("p", "", label));
  if (item.processingStatus === "READY") card.append(action("Открыть документ", "text-button", () => openSource("DOCUMENT", item.contentId)));
  if (item.processingStatus === "PROCESSING") card.append(element("p", "hint", "Статус обновляется каждые 5 секунд, пока открыта эта вкладка."));
  return card;
}

async function askAssistant(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const question = $("rag-question").value.trim();
  if (!question) return;
  const communityId = $("rag-community").value;
  setBusy(form, true);
  clearTimeout(state.ragPollTimer);
  state.ragQueryId = null;
  state.ragPollCount = 0;
  $("rag-result").replaceChildren(textBlock("Передаём вопрос помощнику…"));
  try {
    requireSession();
    const payload = communityId ? { question, communityId: safeId(communityId) } : { question };
    const accepted = await api.request("/v1/rag/queries", { method: "POST", json: payload });
    state.ragQueryId = safeId(accepted.queryId);
    await pollAnswer(state.ragQueryId);
  } catch (error) {
    if (error.status === 503) {
      $("rag-result").replaceChildren(textBlock("Модель поиска или ответа сейчас недоступна. Проверьте настройку сервисов и повторите запрос.", "error"));
    } else report(error, $("rag-result"));
  }
  finally { setBusy(form, false); }
}

async function pollAnswer(queryId) {
  if (state.ragQueryId !== queryId || !state.session) return;
  const session = state.session;
  try {
    const result = await api.request(`/v1/rag/queries/${queryId}`);
    if (state.ragQueryId !== queryId || state.session !== session) return;
    renderAnswer(result);
    if (result.status === "PENDING") {
      state.ragPollCount += 1;
      if (state.ragPollCount < 30) state.ragPollTimer = setTimeout(() => pollAnswer(queryId), 4000);
      else $("rag-result").append(action("Проверить снова", "button button-outline", () => pollAnswer(queryId)));
    }
  } catch (error) {
    if (state.ragQueryId !== queryId) return;
    if (error.status === 410) {
      $("rag-result").replaceChildren(textBlock("Доступ к одному из использованных источников отозван. Сохранённый ответ скрыт."));
    } else report(error, $("rag-result"));
  }
}

function renderAnswer(result) {
  const target = $("rag-result");
  target.replaceChildren();
  const card = element("div", "answer-content");
  const status = ({ PENDING: "ИЩЕМ ИСТОЧНИКИ", COMPLETED: "ОТВЕТ С ИСТОЧНИКАМИ", NO_SOURCES: "ИСТОЧНИКИ НЕ НАЙДЕНЫ", FAILED: "ОШИБКА ОБРАБОТКИ" })[result.status] || result.status;
  append(card, element("p", "eyebrow", status), element("h3", "", result.question));
  if (result.status === "PENDING") card.append(element("p", "muted", "Ищем подходящие фрагменты и проверяем доступ. Страница обновится автоматически."));
  if (result.status === "COMPLETED" || result.status === "NO_SOURCES") card.append(element("p", "answer-text", result.answer || (result.status === "NO_SOURCES" ? "В доступных материалах нет подходящих источников." : "Ответ пока недоступен.")));
  if (result.status === "FAILED") card.append(element("p", "inline-error", "Не удалось подготовить ответ. Попробуйте задать вопрос ещё раз."));
  const citations = Array.isArray(result.citations) ? result.citations : [];
  if (result.status === "COMPLETED" && !citations.length) {
    target.replaceChildren(textBlock("Сервер не приложил проверяемые источники. Ответ скрыт.", "error"));
    return;
  }
  if (result.status === "COMPLETED" && citations.length) {
    const heading = element("h4", "", `Источники · ${citations.length}`);
    card.append(heading);
    const list = element("ol", "citation-list");
    for (const citation of citations) list.append(renderCitation(citation));
    card.append(list);
  }
  target.append(card);
}

function renderCitation(citation) {
  const item = element("li", "citation-card");
  append(item, element("p", "card-kicker", `${citation.kind} · автор #${citation.authorUserId}${citation.pageNo ? ` · стр. ${citation.pageNo}` : ""}`), element("h5", "", citation.title), element("blockquote", "", citation.quote));
  item.append(action("Открыть источник ↗", "text-button", () => openSource(citation.kind, citation.contentId)));
  return item;
}

async function openSource(kind, rawId) {
  const id = safeId(rawId);
  const session = state.session;
  const dialogVersion = ++state.dialogVersion;
  const path = ({ POST: `/v1/posts/${id}`, COMMENT: `/v1/comments/${id}`, DOCUMENT: `/v1/documents/${id}` })[kind];
  if (!path) return report(new ApiError("Неизвестный тип источника."));
  const dialog = $("content-dialog");
  $("dialog-title").textContent = "Проверяем доступ к источнику…";
  $("dialog-content").replaceChildren(textBlock("Загружаем материал…"));
  dialog.showModal();
  try {
    const content = await api.request(path);
    if (!dialog.open || state.session !== session || state.dialogVersion !== dialogVersion) return;
    $("dialog-title").textContent = kind === "DOCUMENT" ? content.title : kind === "COMMENT" ? "Комментарий" : "Публикация";
    const body = element("div", "source-preview");
    append(body, element("p", "card-kicker", `${kind} · #${id}`), element("p", "muted", `Автор #${content.authorUserId}`));
    if (kind === "DOCUMENT") {
      body.append(element("p", "", `Тип: ${content.mimeType}. Версия ${content.versionNo}. Состояние: ${content.processingStatus}.`));
      if (content.processingStatus === "READY") {
        body.append(action("Скачать оригинал", "button button-outline", () => downloadDocument(id)));
      }
    } else body.append(element("p", "post-body", content.body));
    $("dialog-content").replaceChildren(body);
  } catch (error) { report(error, $("dialog-content")); }
}

async function downloadDocument(rawId) {
  // Fetch with the session header; never navigate directly to a bearer-protected URL.
  const id = safeId(rawId);
  const session = state.session;
  const controller = new AbortController();
  state.downloadController?.abort();
  state.downloadController = controller;
  try {
    const token = await api.currentToken();
    if (state.session !== session) return;
    const response = await fetch(`${api.baseUrl}/v1/documents/${id}/file`, {
      headers: { Authorization: `Bearer ${token}` },
      credentials: "omit",
      cache: "no-store",
      signal: controller.signal
    });
    if (state.session !== session) return;
    if (!response.ok) {
      if (response.status === 401) clearSession();
      throw new ApiError(response.status === 404 ? "Файл не найден или недоступен." : `Ошибка загрузки файла (${response.status}).`, response.status);
    }
    const blob = await response.blob();
    if (state.session !== session) return;
    const extension = blob.type === "application/pdf" ? ".pdf" : blob.type.startsWith("text/plain") ? ".txt" : ".docx";
    const filename = `document-${id}${extension}`;
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = objectUrl;
    link.download = filename;
    link.click();
    setTimeout(() => URL.revokeObjectURL(objectUrl), 60000);
  } catch (error) { report(error); }
  finally { if (state.downloadController === controller) state.downloadController = null; }
}

$("session-form").addEventListener("submit", connect);
$("firebase-signin").addEventListener("click", firebaseSignIn);
$("sign-out").addEventListener("click", signOut);
for (const button of document.querySelectorAll("[data-view]")) button.addEventListener("click", () => showView(button.dataset.view));
$("refresh-feed").addEventListener("click", loadFeed);
$("refresh-communities").addEventListener("click", () => loadCommunities(true).catch((error) => report(error, $("community-list"))));
$("more-communities").addEventListener("click", () => loadCommunities(false).catch((error) => report(error, $("community-list"))));
$("create-community-form").addEventListener("submit", createCommunity);
$("join-by-id-form").addEventListener("submit", (event) => { event.preventDefault(); joinCommunity($("join-community-id").value); });
$("document-community").addEventListener("change", (event) => { state.documentCommunityId = event.target.value || null; updateDocumentWriteState(); loadDocuments(true).catch((error) => report(error, $("document-list"))); });
$("more-documents").addEventListener("click", () => loadDocuments(false).catch((error) => report(error, $("document-list"))));
$("document-text-form").addEventListener("submit", (event) => submitDocument(event, "text"));
$("document-file-form").addEventListener("submit", (event) => submitDocument(event, "file"));
$("document-lookup-form").addEventListener("submit", (event) => { event.preventDefault(); checkDocument($("document-lookup-id").value, true).catch((error) => report(error, $("document-status"))); });
$("rag-form").addEventListener("submit", askAssistant);
$("dialog-close").addEventListener("click", () => $("content-dialog").close());
$("content-dialog").addEventListener("close", () => { state.dialogVersion += 1; });
$("content-dialog").addEventListener("click", (event) => { if (event.target === event.currentTarget) event.currentTarget.close(); });
for (const [mode, other, target, otherTarget] of [
  ["text", "file", "document-text-form", "document-file-form"],
  ["file", "text", "document-file-form", "document-text-form"]
]) {
  $("mode-" + mode).addEventListener("click", () => {
    $("mode-" + mode).classList.add("is-active");
    $("mode-" + mode).setAttribute("aria-pressed", "true");
    $("mode-" + other).classList.remove("is-active");
    $("mode-" + other).setAttribute("aria-pressed", "false");
    $(target).hidden = false;
    $(otherTarget).hidden = true;
  });
}
