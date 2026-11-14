# Сайт курсовой и Firebase

Статический интерфейс: лента, сообщества, посты, комментарии, подписки,
реакции и документы. Данные поступают только из SQL API, фиктивных ответов нет.

## Локальный запуск

```sh
cd 03SQL-CourseWork/web/public
python3 -m http.server 8080
```

Откройте `http://localhost:8080`. API запускается отдельно с `ADDR=:8081`,
`CORS_ORIGIN=http://localhost:8080`; в форме укажите `http://localhost:8081/api`.
Документы сохраняются сразу и доступны по действующим правам сообщества.

## Firebase для демонстрации

В `.firebaserc` выбран проект **bivt-labs-sql-coursework**, а
`public/config.js` содержит публичные настройки его Web App. Это не пароль
и не ключ администратора. SQL credentials и ID tokens в Git не добавляйте.

`firebase-demo.html` позволяет показать настоящий Firebase Google Sign-In
независимо от SQL API: вход, UID/email текущего пользователя и выход.
Токен на экран не выводится. Владельцу доступна
[Firebase Console](https://console.firebase.google.com/project/bivt-labs-sql-coursework/authentication/users).
Преподавателю не нужно выдавать административные права: покажите консоль
со своего аккаунта и вход через страницу проверки.

Перед демонстрацией владелец проверяет в Console:

1. Authentication → Sign-in method: Google включён.
2. Authentication → Settings → Authorized domains: домен размещённого
   сайта разрешён. Для локального запуска нужен `localhost` (без порта).
3. Выполнить вход на `firebase-demo.html`; убедиться, что пользователь появился
   в Authentication → Users. Не вставляйте токены в отчёт или скриншоты.
4. Для полной соцсети дополнительно проверить рабочий Go API и SQL.

Вход хранится только в памяти вкладки, SDK обновляет токен перед API-запросами.
Production backend проверяет криптографическую подпись и отзыв, не принимает
unsigned emulator-токены. Firebase emulator в этом PR не подменяет облако.

## Hosting

`firebase.json` публикует только `public/`. В репозитории есть ссылка на
[существующий сайт](https://bivt-labs-sql-coursework.web.app/), но эта ветка
не развёрнута автоматически и не подтверждает состояние облачного проекта.
После review и отдельного решения о публикации:

```sh
cd 03SQL-CourseWork/web
firebase deploy --only hosting --project bivt-labs-sql-coursework
```

`backendReady: false` честно показывает, что публичный API ещё не проверен.
Firebase Hosting не выполняет Go и не имеет настроенного `/api` rewrite.
В `config.js` укажите полный HTTPS `apiBaseUrl`, настройте его точный CORS
origin и проверьте `/readyz`/вход/CRUD, прежде чем выставлять `backendReady: true`.
Максимальный размер документа задаётся `maxDocumentBytes` (до 10 МиБ) и
не должен превышать лимит API/хостинга.

## Проверки без облака

Из корня репозитория:

```sh
for file in 03SQL-CourseWork/web/public/*.js; do node --input-type=module --check < "$file"; done
node 03SQL-CourseWork/web/check-config.cjs
```

Эти проверки подтверждают синтаксис и согласованность конфигурации,
но не подтверждают доступность Firebase provider, API или базы.
