# Лабораторная работа №8: RSS Reader с MySQL

## Описание

RSS-ридер с графическим интерфейсом на Avalonia UI и базой данных MySQL для получения максимального балла (+4 points).

**Студент:** Кирюшин Д.А.  
**Группа:** БИВТ-23-10  
**Дата:** 26.04.2026

## Особенности реализации (усложненный вариант +4 балла):

1. ✅ **MySQL вместо SQLite** - используется через Docker контейнер
2. ✅ **HttpWebRequest/HttpWebResponse** - согласно примеру кода в задании  
3. ✅ **System.Xml для парсинга** - XmlDocument для работы с XML
4. ✅ **Avalonia UI** - кроссплатформенный графический интерфейс
5. ✅ **Полный функционал:**
   - Загрузка RSS с любого URL и отображение полного XML
   - Парсинг и отображение структурированных новостей
   - Сохранение в MySQL БД (с удалением старых)
   - Загрузка всех новостей из БД

## Структура проекта

```
02C#/lab08/
├── docker-compose.yml         # MySQL контейнер
├── RssReaderApp/
│   ├── RssReaderApp.csproj
│   ├── Models/
│   │   └── NewsItem.cs       # Модель новости
│   ├── Services/
│   │   ├── RssService.cs     # Загрузка RSS (HttpWebRequest)
│   │   ├── XmlParser.cs      # Парсинг XML
│   │   └── DatabaseManager.cs # Работа с MySQL
│   ├── Views/
│   │   ├── MainWindow.axaml  # GUI
│   │   └── MainWindow.axaml.cs
│   ├── App.axaml
│   ├── App.axaml.cs
│   └── Program.cs
└── README.md
```

## Структура БД MySQL

```sql
CREATE DATABASE IF NOT EXISTS rss_news;
USE rss_news;

CREATE TABLE news (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    link VARCHAR(500),
    pub_date DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pub_date (pub_date)
);
```

**Таблица `news`:**
- `id` (INT, PRIMARY KEY, AUTO_INCREMENT) - уникальный идентификатор
- `title` (VARCHAR(500), NOT NULL) - заголовок новости
- `description` (TEXT) - аннотация/описание
- `link` (VARCHAR(500)) - ссылка на полную новость
- `pub_date` (DATETIME) - дата и время публикации
- `created_at` (TIMESTAMP) - время добавления в БД
- INDEX на `pub_date` для быстрой сортировки

## Запуск приложения

### 1. Запуск MySQL через Docker

```bash
cd 02C#/lab08
docker compose up -d
```

Проверка что контейнер запущен:
```bash
docker ps
```

### 2. Запуск приложения

```bash
cd RssReaderApp
dotnet run
```

### 3. Остановка MySQL

```bash
cd 02C#/lab08
docker compose down
```

## Использование

1. **Загрузка RSS:**
   - Введите URL RSS-ленты (по умолчанию: https://lenta.ru/rss/news)
   - Нажмите "Загрузить RSS"
   - Полный XML отобразится в первом окне

2. **Парсинг XML:**
   - После загрузки RSS нажмите "Распарсить XML"
   - Новости отобразятся в структурированном виде

3. **Сохранение в БД:**
   - После парсинга нажмите "Сохранить в БД"
   - Старые новости будут удалены, новые - добавлены

4. **Загрузка из БД:**
   - Нажмите "Загрузить из БД"
   - Все новости из БД отобразятся в нижнем окне

## Зависимости (NuGet)

- Avalonia 11.3.2
- MySql.Data 9.7.0

## Технологии

- **C# .NET 8.0+**
- **Avalonia UI** - кроссплатформенный UI фреймворк
- **MySQL 8.0** - СУБД
- **Docker** - контейнеризация БД
- **HttpWebRequest/HttpWebResponse** - загрузка RSS
- **System.Xml** - парсинг XML
- **MySql.Data** - .NET connector для MySQL

## Скриншоты для отчета

### Код:
1. docker-compose.yml
2. NewsItem.cs
3. RssService.cs
4. XmlParser.cs  
5. DatabaseManager.cs
6. MainWindow.axaml
7. MainWindow.axaml.cs
8. Структура БД (CREATE TABLE)

### Работа приложения:
1. Docker контейнер с MySQL
2. Окно приложения с адресом RSS
3. Загруженный полный XML
4. Распарсенные новости
5. Сообщение о сохранении в БД
6. Загруженные новости из БД
7. Содержимое таблицы news в БД
8. Структура таблицы (DESCRIBE news)
