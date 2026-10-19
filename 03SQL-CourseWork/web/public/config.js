// Public runtime configuration. Never put SQL, OIDC client secrets or LLM keys here.
window.COURSEWORK_CONFIG = Object.freeze({
  apiBaseUrl: "/api",
  backendReady: false,
  maxDocumentBytes: 10 * 1024 * 1024,
  firebaseConfig: Object.freeze({
    apiKey: "AIzaSyDilm6obxFuAeAuqnXEHWvqG21ftGo-REE",
    authDomain: "bivt-labs-sql-coursework.firebaseapp.com",
    projectId: "bivt-labs-sql-coursework",
    appId: "1:820033394421:web:ccaf44443c9e32d43d17bc"
  })
});
