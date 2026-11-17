// Read-only consistency check: no token, credentials, or cloud requests.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const context = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "public/config.js"), "utf8"), context);
const config = context.window.COURSEWORK_CONFIG;
const projects = JSON.parse(fs.readFileSync(path.join(__dirname, ".firebaserc"), "utf8"));
const hosting = JSON.parse(fs.readFileSync(path.join(__dirname, "firebase.json"), "utf8"));
assert.equal(config.firebaseConfig.projectId, projects.projects.default);
assert.equal(config.firebaseConfig.authDomain, `${projects.projects.default}.firebaseapp.com`);
assert.match(config.firebaseConfig.appId, /^1:[0-9]+:web:[a-zA-Z0-9]+$/);
assert.ok(config.firebaseConfig.apiKey);
assert.equal(hosting.hosting.public, "public");
assert.ok(config.maxDocumentBytes > 0 && config.maxDocumentBytes <= 10485760);
assert.ok(config.apiBaseUrl === "/api" || /^https:\/\//.test(config.apiBaseUrl) || /^http:\/\/localhost:\d+\/api$/.test(config.apiBaseUrl));
console.log("Firebase config: project, app, Hosting directory and runtime configuration agree");
