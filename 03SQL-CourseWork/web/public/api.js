export class ApiError extends Error {
  constructor(message, status = 0, code = "NETWORK_ERROR") {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

export class ApiClient {
  constructor(baseUrl, onUnauthorized) {
    this.baseUrl = normalizeBaseUrl(baseUrl);
    this.accessToken = null;
    this.tokenProvider = null;
    this.pending = new Set();
    this.generation = 0;
    this.onUnauthorized = onUnauthorized;
  }

  setBaseUrl(value) {
    this.baseUrl = normalizeBaseUrl(value);
  }

  setAccessToken(value) {
    this.accessToken = value || null;
  }

  setTokenProvider(provider) {
    this.tokenProvider = provider || null;
  }

  async currentToken() {
    if (this.tokenProvider) this.accessToken = await this.tokenProvider();
    return this.accessToken;
  }

  cancelPending() {
    this.generation += 1;
    for (const controller of this.pending) controller.abort();
    this.pending.clear();
  }

  async request(path, { method = "GET", json, form, signal } = {}) {
    const generation = this.generation;
    if (!/^\/v1\/[a-zA-Z0-9/_-]+(?:\?[a-zA-Z0-9=&%._~-]+)?$/.test(path)) {
      throw new ApiError("Некорректный путь API.", 0, "INVALID_PATH");
    }
    const headers = { Accept: "application/json" };
    const token = await this.currentToken();
    if (generation !== this.generation) throw new DOMException("Запрос отменён.", "AbortError");
    if (token) headers.Authorization = `Bearer ${token}`;
    if (json !== undefined) headers["Content-Type"] = "application/json";
    let response;
    const controller = new AbortController();
    const abortWithCaller = () => controller.abort();
    signal?.addEventListener("abort", abortWithCaller, { once: true });
    this.pending.add(controller);
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        method,
        headers,
        body: json !== undefined ? JSON.stringify(json) : form,
        signal: controller.signal,
        cache: "no-store",
        credentials: "omit"
      });
    } catch (error) {
      if (error.name === "AbortError") throw error;
      throw new ApiError("Сервер недоступен. Проверьте адрес API и подключение.");
    } finally {
      this.pending.delete(controller);
      signal?.removeEventListener("abort", abortWithCaller);
    }
    if (response.status === 204) return null;
    let payload = null;
    try {
      payload = await response.json();
    } catch {
      if (response.ok) throw new ApiError("Сервер вернул ответ не в формате JSON.", response.status, "BAD_RESPONSE");
    }
    if (!response.ok) {
      if (response.status === 401 && this.accessToken) this.onUnauthorized?.();
      const message = typeof payload?.message === "string" ? payload.message : defaultError(response.status);
      throw new ApiError(message, response.status, payload?.code || "HTTP_ERROR");
    }
    return payload;
  }
}

function normalizeBaseUrl(value) {
  const trimmed = String(value || "").trim().replace(/\/+$/, "");
  if (!trimmed) throw new ApiError("Укажите адрес API.", 0, "INVALID_BASE_URL");
  if (trimmed.startsWith("/") && !trimmed.startsWith("//")) return trimmed;
  let parsed;
  try { parsed = new URL(trimmed); } catch { throw new ApiError("Укажите относительный путь или полный URL API.", 0, "INVALID_BASE_URL"); }
  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new ApiError("Адрес API не должен содержать учётные данные или параметры.", 0, "INVALID_BASE_URL");
  }
  if (parsed.protocol !== "https:" && !(parsed.protocol === "http:" && ["localhost", "127.0.0.1"].includes(parsed.hostname))) {
    throw new ApiError("Для удалённого API нужен HTTPS.", 0, "INVALID_BASE_URL");
  }
  return trimmed;
}

function defaultError(status) {
  if (status === 401) return "Сессия завершилась. Подключитесь снова.";
  if (status === 403) return "Недостаточно прав для этого действия.";
  if (status === 404) return "Материал не найден или недоступен.";
  if (status === 410) return "Доступ к одному из источников ответа отозван.";
  if (status === 429) return "Слишком много запросов. Повторите позже.";
  return `Ошибка сервера (${status}).`;
}
