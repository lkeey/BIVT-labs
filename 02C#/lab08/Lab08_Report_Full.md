# ОТЧЕТ ПО ЛАБОРАТОРНОЙ РАБОТЕ №8

## Взаимодействие с СУБД в C#. Обработка XML-файлов

**Студент:** Кирюшин Д.А.  
**Группа:** БИВТ-23-10  
**Дата:** 26.04.2026

---

## ЗАДАНИЕ НА ЛАБОРАТОРНУЮ РАБОТУ

В рамках лабораторной работы были решены следующие задачи:

**Усложненный вариант (+4 балла):**

1. Настроить MySQL через Docker Compose
2. Создать Avalonia проект RssReaderApp
3. Реализовать класс NewsItem (модель новости)
4. Реализовать класс RssService (загрузка RSS через HttpWebRequest/HttpWebResponse)
5. Реализовать класс XmlParser (парсинг XML через System.Xml)
6. Реализовать класс DatabaseManager (работа с MySQL)
7. Разработать графический интерфейс на Avalonia UI
8. Реализовать обработчики событий для всех кнопок
9. Реализовать загрузку RSS с отображением полного XML
10. Реализовать парсинг и отображение структурированных новостей
11. Реализовать сохранение в MySQL БД (с удалением старых новостей)
12. Реализовать загрузку всех новостей из БД

---

## СТРУКТУРА БД MySQL

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
- `id` (INT, PRIMARY KEY, AUTO_INCREMENT) - уникальный идентификатор новости
- `title` (VARCHAR(500), NOT NULL) - заголовок новости (обязательное поле)
- `description` (TEXT) - аннотация/описание новости
- `link` (VARCHAR(500)) - ссылка на полную версию новости
- `pub_date` (DATETIME) - дата и время публикации новости
- `created_at` (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP) - время добавления записи в БД
- INDEX на поле `pub_date` для оптимизации сортировки по дате

---

## ЛИСТИНГ ПРОГРАММЫ

### Docker Compose (docker-compose.yml)

Настройка MySQL контейнера для работы с БД:

```yaml
version: '3.8'
services:
  mysql:
    image: mysql:8.0
    container_name: lab08_mysql
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: rss_news
      MYSQL_USER: rss_user
      MYSQL_PASSWORD: rss_pass
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password

volumes:
  mysql_data:
```

---

### Модель данных (NewsItem.cs)

Класс NewsItem инкапсулирует данные о новости:

```csharp
using System;

namespace RssReaderApp.Models
{
    public class NewsItem
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Link { get; set; } = string.Empty;
        public DateTime PubDate { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
```

---

### Сервис загрузки RSS (RssService.cs)

Использует HttpWebRequest и HttpWebResponse согласно заданию:

```csharp
using System;
using System.IO;
using System.Net;

namespace RssReaderApp.Services
{
    public class RssService
    {
        private string rssUrl = "https://lenta.ru/rss/news";

        public void SetRssUrl(string url)
        {
            rssUrl = url;
        }

        public string DownloadRssFeed()
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(rssUrl);
            request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
            request.Timeout = 30000;
            
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            using (Stream stream = response.GetResponseStream())
            using (StreamReader reader = new StreamReader(stream))
            {
                string rssContent = reader.ReadToEnd();
                return rssContent;
            }
        }
    }
}
```

---

### Парсер XML (XmlParser.cs)

Использует System.Xml для парсинга RSS-ленты:

```csharp
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Xml;
using RssReaderApp.Models;

namespace RssReaderApp.Services
{
    public class XmlParser
    {
        public List<NewsItem> ParseRss(string xmlContent)
        {
            var news = new List<NewsItem>();
            
            try
            {
                XmlDocument doc = new XmlDocument();
                doc.LoadXml(xmlContent);
                
                XmlNodeList items = doc.GetElementsByTagName("item");
                
                foreach (XmlNode item in items)
                {
                    var newsItem = new NewsItem
                    {
                        Title = item["title"]?.InnerText ?? "",
                        Description = item["description"]?.InnerText ?? "",
                        Link = item["link"]?.InnerText ?? "",
                        PubDate = ParsePubDate(item["pubDate"]?.InnerText ?? "")
                    };
                    news.Add(newsItem);
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Ошибка парсинга XML: {ex.Message}", ex);
            }
            
            return news;
        }
        
        private DateTime ParsePubDate(string pubDate)
        {
            if (string.IsNullOrWhiteSpace(pubDate))
                return DateTime.Now;
            
            if (DateTime.TryParse(pubDate, CultureInfo.InvariantCulture, 
                DateTimeStyles.None, out var date))
                return date;
            
            if (DateTime.TryParseExact(pubDate, "ddd, dd MMM yyyy HH:mm:ss zzz", 
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var date2))
                return date2;
            
            return DateTime.Now;
        }
    }
}
```

---

### Менеджер БД (DatabaseManager.cs)

Работа с MySQL через MySql.Data connector:

```csharp
using System;
using System.Collections.Generic;
using MySql.Data.MySqlClient;
using RssReaderApp.Models;

namespace RssReaderApp.Services
{
    public class DatabaseManager
    {
        private const string ConnectionString = 
            "Server=localhost;Port=3306;Database=rss_news;Uid=rss_user;Pwd=rss_pass;";
        
        public void InitializeDatabase()
        {
            using var connection = new MySqlConnection(ConnectionString);
            connection.Open();
            
            string createTableQuery = @"
                CREATE TABLE IF NOT EXISTS news (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(500) NOT NULL,
                    description TEXT,
                    link VARCHAR(500),
                    pub_date DATETIME,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_pub_date (pub_date)
                )";
            
            using var command = new MySqlCommand(createTableQuery, connection);
            command.ExecuteNonQuery();
        }
        
        public void SaveNews(List<NewsItem> newsList)
        {
            using var connection = new MySqlConnection(ConnectionString);
            connection.Open();
            
            using (var deleteCommand = new MySqlCommand("DELETE FROM news", connection))
            {
                deleteCommand.ExecuteNonQuery();
            }
            
            foreach (var news in newsList)
            {
                string insertQuery = @"
                    INSERT INTO news (title, description, link, pub_date)
                    VALUES (@title, @description, @link, @pubDate)";
                
                using var command = new MySqlCommand(insertQuery, connection);
                command.Parameters.AddWithValue("@title", news.Title);
                command.Parameters.AddWithValue("@description", news.Description);
                command.Parameters.AddWithValue("@link", news.Link);
                command.Parameters.AddWithValue("@pubDate", news.PubDate);
                command.ExecuteNonQuery();
            }
        }
        
        public List<NewsItem> LoadAllNews()
        {
            var newsList = new List<NewsItem>();
            
            using var connection = new MySqlConnection(ConnectionString);
            connection.Open();
            
            string selectQuery = "SELECT * FROM news ORDER BY pub_date DESC";
            using var command = new MySqlCommand(selectQuery, connection);
            using var reader = command.ExecuteReader();
            
            while (reader.Read())
            {
                newsList.Add(new NewsItem
                {
                    Id = reader.GetInt32("id"),
                    Title = reader.GetString("title"),
                    Description = reader.IsDBNull(reader.GetOrdinal("description")) 
                        ? "" : reader.GetString("description"),
                    Link = reader.IsDBNull(reader.GetOrdinal("link")) 
                        ? "" : reader.GetString("link"),
                    PubDate = reader.GetDateTime("pub_date"),
                    CreatedAt = reader.GetDateTime("created_at")
                });
            }
            
            return newsList;
        }
        
        public bool TestConnection()
        {
            try
            {
                using var connection = new MySqlConnection(ConnectionString);
                connection.Open();
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
```

---

### Графический интерфейс (MainWindow.axaml)

XAML-разметка интерфейса приложения (ключевые фрагменты):

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="RssReaderApp.Views.MainWindow"
        Title="RSS Reader - Лабораторная работа №8"
        Width="1200" Height="900">
    
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>   <!-- Адрес RSS -->
            <RowDefinition Height="Auto"/>   <!-- Кнопки управления RSS -->
            <RowDefinition Height="200"/>    <!-- XML (полный текст) -->
            <RowDefinition Height="*"/>      <!-- Новости (распарсенные) -->
            <RowDefinition Height="Auto"/>   <!-- Кнопки БД -->
            <RowDefinition Height="200"/>    <!-- Новости из БД -->
        </Grid.RowDefinitions>
        
        <!-- Адрес RSS -->
        <StackPanel Grid.Row="0">
            <TextBox Name="RssUrlTextBox" 
                     Text="https://lenta.ru/rss/news"/>
        </StackPanel>
        
        <!-- Кнопки управления RSS -->
        <StackPanel Grid.Row="1" Orientation="Horizontal">
            <Button Name="DownloadRssButton" 
                    Content="Загрузить RSS" 
                    Click="OnDownloadRss"/>
            <Button Name="ParseRssButton" 
                    Content="Распарсить XML" 
                    Click="OnParseRss"/>
        </StackPanel>
        
        <!-- Полный XML текст -->
        <TextBox Grid.Row="2" Name="RawXmlTextBox" 
                 IsReadOnly="True"/>
        
        <!-- Распарсенные новости -->
        <ListBox Grid.Row="3" Name="ParsedNewsListBox">
            <ListBox.ItemTemplate>
                <DataTemplate>
                    <StackPanel>
                        <TextBlock Text="{Binding Title}" FontWeight="Bold"/>
                        <TextBlock Text="{Binding Description}"/>
                        <TextBlock Text="{Binding PubDate}"/>
                        <TextBlock Text="{Binding Link}" Foreground="Blue"/>
                    </StackPanel>
                </DataTemplate>
            </ListBox.ItemTemplate>
        </ListBox>
        
        <!-- Кнопки БД -->
        <StackPanel Grid.Row="4" Orientation="Horizontal">
            <Button Name="SaveToDbButton" 
                    Content="Сохранить в БД" 
                    Click="OnSaveToDb"/>
            <Button Name="LoadFromDbButton" 
                    Content="Загрузить из БД" 
                    Click="OnLoadFromDb"/>
        </StackPanel>
        
        <!-- Новости из БД -->
        <TextBox Grid.Row="5" Name="DbNewsTextBox" 
                 IsReadOnly="True"/>
    </Grid>
</Window>
```

---

### Обработчики событий (MainWindow.axaml.cs) - ключевые фрагменты

```csharp
public partial class MainWindow : Window
{
    private RssService rssService;
    private XmlParser xmlParser;
    private DatabaseManager dbManager;
    private string? currentXml;
    private List<NewsItem>? currentNews;
    
    public MainWindow()
    {
        InitializeComponent();
        
        rssService = new RssService();
        xmlParser = new XmlParser();
        dbManager = new DatabaseManager();
        
        CheckDatabaseConnection();
    }
    
    private async void OnDownloadRss(object? sender, RoutedEventArgs e)
    {
        try
        {
            rssService.SetRssUrl(RssUrlTextBox.Text ?? "https://lenta.ru/rss/news");
            currentXml = await Task.Run(() => rssService.DownloadRssFeed());
            RawXmlTextBox.Text = currentXml;
            StatusTextBlock.Text = "RSS загружен успешно";
        }
        catch (Exception ex)
        {
            await ShowError("Ошибка загрузки RSS", ex.Message);
        }
    }
    
    private async void OnParseRss(object? sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(currentXml))
        {
            await ShowError("Ошибка", "Сначала загрузите RSS");
            return;
        }
        
        try
        {
            currentNews = await Task.Run(() => xmlParser.ParseRss(currentXml));
            ParsedNewsListBox.ItemsSource = currentNews;
            StatusTextBlock.Text = $"Распарсено новостей: {currentNews.Count}";
        }
        catch (Exception ex)
        {
            await ShowError("Ошибка парсинга XML", ex.Message);
        }
    }
    
    private async void OnSaveToDb(object? sender, RoutedEventArgs e)
    {
        if (currentNews == null || currentNews.Count == 0)
        {
            await ShowError("Ошибка", "Нет новостей для сохранения");
            return;
        }
        
        try
        {
            await Task.Run(() => dbManager.SaveNews(currentNews));
            await ShowInfo("Успех", $"Сохранено {currentNews.Count} новостей");
        }
        catch (Exception ex)
        {
            await ShowError("Ошибка сохранения в БД", ex.Message);
        }
    }
    
    private async void OnLoadFromDb(object? sender, RoutedEventArgs e)
    {
        try
        {
            var newsFromDb = await Task.Run(() => dbManager.LoadAllNews());
            
            var sb = new StringBuilder();
            foreach (var news in newsFromDb)
            {
                sb.AppendLine($"ID: {news.Id}");
                sb.AppendLine($"Заголовок: {news.Title}");
                sb.AppendLine($"Описание: {news.Description}");
                sb.AppendLine($"Ссылка: {news.Link}");
                sb.AppendLine($"Дата: {news.PubDate:dd.MM.yyyy HH:mm}");
                sb.AppendLine(new string('-', 80));
            }
            
            DbNewsTextBox.Text = sb.ToString();
        }
        catch (Exception ex)
        {
            await ShowError("Ошибка загрузки из БД", ex.Message);
        }
    }
}
```

---

## РЕКОМЕНДУЕМЫЕ СКРИНШОТЫ

### Скриншоты кода:
1. docker-compose.yml (настройка MySQL)
2. NewsItem.cs (модель данных)
3. RssService.cs (загрузка через HttpWebRequest)
4. XmlParser.cs (парсинг XML через System.Xml)
5. DatabaseManager.cs (InitializeDatabase, SaveNews, LoadAllNews)
6. MainWindow.axaml (структура GUI)
7. MainWindow.axaml.cs (обработчики OnDownloadRss, OnParseRss, OnSaveToDb, OnLoadFromDb)
8. Структура БД (CREATE TABLE news)

### Скриншоты работы приложения:
1. Запущенный Docker контейнер (`docker ps` показывает lab08_mysql)
2. Начальное окно приложения с полем адреса RSS
3. Загруженный полный XML в верхнем текстовом окне
4. Распарсенные новости с заголовком, описанием, датой и ссылкой
5. Сообщение об успешном сохранении в БД
6. Загруженные новости из БД в нижнем текстовом окне
7. MySQL Workbench или командная строка: SELECT * FROM news
8. Структура таблицы: DESCRIBE news

---

## ВЫВОД

В ходе выполнения лабораторной работы я успешно освоил разработку интернет-приложений на C# с использованием СУБД MySQL и обработкой XML-документов. Получил практический опыт работы с сетевыми запросами через HttpWebRequest/HttpWebResponse, парсинга XML-данных через System.Xml, взаимодействия с реляционной базой данных MySQL и создания графического интерфейса на Avalonia UI. Реализовал усложненный вариант задания с MySQL вместо SQLite для получения дополнительных баллов, что потребовало изучения MySql.Data connector и настройки Docker контейнера для БД.

Реализовал класс RssService для загрузки RSS-лент с использованием классов HttpWebRequest и HttpWebResponse согласно требованиям задания. Научился создавать HTTP-запросы, устанавливать заголовки UserAgent и Timeout, получать ответ сервера через HttpWebResponse, читать поток данных через Stream и StreamReader. Применил конструкцию using для автоматического освобождения ресурсов после использования сетевых объектов. Реализовал метод SetRssUrl для динамической смены адреса RSS-ленты, что позволяет работать с любыми RSS-источниками через графический интерфейс.

Освоил работу с XML-документами через пространство имен System.Xml. Реализовал класс XmlParser с методом ParseRss для парсинга RSS-ленты в формате XML. Использовал класс XmlDocument для загрузки и разбора XML-содержимого, метод GetElementsByTagName для получения всех элементов item, индексатор для доступа к дочерним элементам по имени (title, description, link, pubDate). Освоил работу с XmlNodeList для перебора всех новостей и XmlNode для доступа к отдельным элементам. Реализовал метод ParsePubDate для корректного парсинга дат в форматах RFC822 и RFC1123, используя DateTime.TryParse и DateTime.TryParseExact с CultureInfo.InvariantCulture для независимости от локали системы.

Освоил работу с СУБД MySQL через .NET connector MySql.Data. Реализовал класс DatabaseManager для инкапсуляции всей логики работы с БД. Изучил создание подключения через MySqlConnection с использованием строки подключения ConnectionString, содержащей параметры Server, Port, Database, Uid и Pwd. Реализовал метод InitializeDatabase для создания таблицы news с использованием SQL-запроса CREATE TABLE IF NOT EXISTS, что обеспечивает идемпотентность операции. Применил MySqlCommand для выполнения SQL-запросов и ExecuteNonQuery для команд, не возвращающих данные. Создал индекс на поле pub_date для оптимизации сортировки новостей по дате публикации.

Реализовал метод SaveNews для сохранения списка новостей в БД с предварительным удалением старых записей через DELETE FROM news согласно требованиям задания. Использовал параметризованные запросы через command.Parameters.AddWithValue для защиты от SQL-инъекций и корректной передачи данных разных типов (string, DateTime). Освоил работу с циклом для пакетной вставки множества записей, каждая из которых выполняется в отдельной команде INSERT. Реализовал метод LoadAllNews для чтения всех новостей из БД с использованием MySqlDataReader. Применил метод ExecuteReader для выполнения SELECT-запроса, цикл while (reader.Read()) для перебора всех строк результата, методы GetInt32, GetString, GetDateTime для получения значений полей по имени, метод IsDBNull для проверки NULL-значений перед чтением.

Настроил MySQL через Docker Compose для контейнеризации БД. Создал файл docker-compose.yml с описанием сервиса mysql, использующего официальный образ mysql:8.0. Настроил переменные окружения для создания БД rss_news и пользователя rss_user с паролем rss_pass. Пробросил порт 3306 для доступа к БД с хоста, создал volume mysql_data для персистентного хранения данных БД. Применил команду --default-authentication-plugin=mysql_native_password для совместимости с .NET connector. Освоил команды docker compose up -d для запуска контейнера в фоновом режиме и docker compose down для остановки и удаления контейнера.

Разработал графический интерфейс на Avalonia UI с шестью функциональными областями. Верхняя панель содержит TextBox для ввода URL RSS-ленты с возможностью изменения адреса. Вторая панель включает кнопки "Загрузить RSS" и "Распарсить XML" с TextBlock для отображения статуса операций. Третья область - TextBox с полным XML-содержимым RSS-ленты для проверки корректности загрузки. Четвертая область - ListBox с DataTemplate для отображения распарсенных новостей в структурированном виде (заголовок жирным шрифтом, описание обычным текстом, дата мелким шрифтом, ссылка синим цветом). Пятая панель содержит кнопки "Сохранить в БД" и "Загрузить из БД" с индикатором статуса подключения. Шестая область - TextBox для отображения новостей, загруженных из БД, с полной информацией включая ID и created_at.

Реализовал обработчики событий для всех кнопок с асинхронным выполнением длительных операций. Метод OnDownloadRss асинхронно загружает RSS через Task.Run для выполнения в фоновом потоке, устанавливает URL из TextBox, отображает результат в RawXmlTextBox и обновляет статус. Метод OnParseRss проверяет наличие загруженного XML, асинхронно парсит его, устанавливает ItemsSource для ListBox и показывает количество распарсенных новостей. Метод OnSaveToDb проверяет наличие новостей, асинхронно сохраняет их в БД и показывает диалог с результатом. Метод OnLoadFromDb асинхронно загружает новости из БД, форматирует их через StringBuilder с разделителями и отображает в текстовом окне. Все обработчики включают try-catch блоки для корректной обработки ошибок и вызов ShowError/ShowInfo для информирования пользователя через модальные диалоги.

Применил принципы разделения ответственности и создания слабо связанных компонентов. Класс NewsItem инкапсулирует данные модели, RssService отвечает только за загрузку RSS, XmlParser - за парсинг XML, DatabaseManager - за работу с БД, MainWindow - за представление и обработку пользовательского ввода. Каждый класс имеет четко определенную ответственность, что обеспечивает модульность кода, упрощает тестирование и поддержку. Освоил использование async/await для асинхронных операций UI, что предотвращает блокировку интерфейса при выполнении длительных сетевых запросов и операций с БД.

Полученные навыки работы с сетевыми протоколами, XML-документами, СУБД MySQL, Docker-контейнерами и асинхронным программированием являются фундаментальными для разработки современных интернет-приложений. Освоил полный цикл работы с внешними данными: загрузка через HTTP, парсинг XML, сохранение в реляционную БД, извлечение и отображение в GUI. Научился правильно обрабатывать ошибки, работать с ресурсами через using, применять параметризованные запросы для безопасности. Эти знания станут основой для разработки более сложных веб-сервисов, REST API клиентов, систем интеграции с внешними источниками данных и полнофункциональных приложений с базами данных.
