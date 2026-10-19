// Firebase Web SDK 12.19.0 from the official CDN. Only loaded when configured.
import { initializeApp, getApps } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js";
import { initializeAuth, inMemoryPersistence, browserPopupRedirectResolver, GoogleAuthProvider, signInWithPopup, signOut } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";

let auth;

export async function signInWithGoogle(config) {
  if (!auth) {
    const app = getApps()[0] || initializeApp(config);
    auth = initializeAuth(app, {
      persistence: inMemoryPersistence,
      popupRedirectResolver: browserPopupRedirectResolver
    });
  }
  const result = await signInWithPopup(auth, new GoogleAuthProvider());
  return {
    token: await result.user.getIdToken(),
    tokenProvider: () => result.user.getIdToken()
  };
}

export async function signOutGoogle() {
  if (auth) await signOut(auth);
}
