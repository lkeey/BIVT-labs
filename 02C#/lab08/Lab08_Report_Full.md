# Лабораторная работа №8
## Взаимодействие с СУБД в C#. Обработка XML-файлов

**Студент:** [Ваше ФИО]  
**Группа:** [Ваша группа]  
**Вариант:** Усложненное задание (+4 балла) с использованием MySQL

---

## Задание

Разработать приложение с графическим интерфейсом для работы с RSS-лентой новостей, которое:

1. Загружает RSS-ленту с сервера (https://lenta.ru/rss/news) с использованием классов `HttpWebRequest` и `HttpWebResponse`
2. Выводит полный XML-текст ленты в текстовом окне
3. Парсит XML с использованием `System.Xml` и выводит структурированную информацию (заголовок, аннотация, дата/время, ссылка)
4. Использует СУБД **MySQL** (вместо SQLite для получения +4 балла)
5. Предоставляет возможность записи новостей в БД (с удалением старых) и чтения всех новостей из БД

---

## В рамках лабораторной работы были решены следующие задачи

1. **Настроить окружение MySQL**  
   - Установить MySQL через Homebrew
   - Создать базу данных `rss_news`
   - Создать пользователя `rss_user` с необходимыми правами

2. **Создать модель данных `NewsItem`**  
   - Определить структуру новости с полями: Id, Title, Description, Link, PubDate, CreatedAt

3. **Реализовать класс `RssService` для загрузки RSS**  
   - Использовать `HttpWebRequest` и `HttpWebResponse` для получения XML
   - Настроить UserAgent и Timeout для корректной работы

4. **Реализовать класс `XmlParser` для парсинга XML**  
   - Использовать `System.Xml.XmlDocument` для обработки XML
   - Извлечь данные из тегов `<item>`: title, description, link, pubDate
   - Реализовать надежный парсинг даты в формате RFC822/RFC1123

5. **Реализовать класс `DatabaseManager` для работы с MySQL**  
   - Создать таблицу `news` с необходимыми полями
   - Реализовать метод `SaveNews` (удаление старых + вставка новых)
   - Реализовать метод `LoadAllNews` для чтения всех записей
   - Добавить метод `TestConnection` для проверки подключения

6. **Разработать графический интерфейс на Avalonia UI**  
   - Создать форму с текстовым полем для URL RSS-ленты
   - Добавить кнопки "Загрузить RSS" и "Распарсить XML"
   - Создать область для отображения полного XML-текста
   - Реализовать `ListBox` с `DataTemplate` для красивого отображения распарсенных новостей
   - Добавить кнопки "Сохранить в БД" и "Загрузить из БД"
   - Создать текстовое окно для вывода новостей из базы данных

7. **Реализовать асинхронную обработку**  
   - Применить `async`/`await` для всех сетевых и БД операций
   - Использовать `Task.Run` для выполнения долгих операций в фоновом потоке
   - Обеспечить отзывчивость интерфейса во время загрузки данных

8. **Добавить обработку ошибок**  
   - Реализовать кастомные диалоговые окна для ошибок и информации
   - Добавить статусные `TextBlock` для отображения текущего состояния операций
   - Обеспечить корректную работу при отсутствии подключения к БД

---

## Структура базы данных MySQL

### Таблица `news`

| Поле | Тип | Описание | Особенности |
|------|-----|----------|-------------|
| `id` | INT | Уникальный идентификатор | PRIMARY KEY, AUTO_INCREMENT |
| `title` | VARCHAR(500) | Заголовок новости | NOT NULL |
| `description` | TEXT | Описание/аннотация | NULL допустим |
| `link` | VARCHAR(500) | Ссылка на полную новость | NULL допустим |
| `pub_date` | DATETIME | Дата публикации новости | Индексируется |
| `created_at` | TIMESTAMP | Время добавления в БД | DEFAULT CURRENT_TIMESTAMP |

### SQL команда создания таблицы

```sql
CREATE TABLE IF NOT EXISTS news (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    link VARCHAR(500),
    pub_date DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pub_date (pub_date)
);
```

### Настройка базы данных

```bash
# Создание БД и пользователя
mysql -u root -e "CREATE DATABASE IF NOT EXISTS rss_news CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -e "CREATE USER IF NOT EXISTS 'rss_user'@'localhost' IDENTIFIED BY 'rss_pass';"
mysql -u root -e "GRANT ALL PRIVILEGES ON rss_news.* TO 'rss_user'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
```

---

## Листинг программы

### 1. docker-compose.yml (альтернативный вариант установки MySQL)

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

### 2. Models/NewsItem.cs

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

### 3. Services/RssService.cs

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

### 4. Services/XmlParser.cs

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
            
            // Попытка парсинга RFC822 формата (стандарт RSS)
            if (DateTime.TryParse(pubDate, CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
                return date;
            
            // Попытка парсинга с учетом RFC1123
            if (DateTime.TryParseExact(pubDate, "ddd, dd MMM yyyy HH:mm:ss zzz", 
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var date2))
                return date2;
            
            return DateTime.Now;
        }
    }
}
```

### 5. Services/DatabaseManager.cs

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
            
            // Удаление старых новостей
            using (var deleteCommand = new MySqlCommand("DELETE FROM news", connection))
            {
                deleteCommand.ExecuteNonQuery();
            }
            
            // Вставка новых новостей
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

### 6. Views/MainWindow.axaml

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:models="clr-namespace:RssReaderApp.Models"
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
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Адрес RSS-ленты:" FontWeight="Bold" Margin="0,0,0,5"/>
            <TextBox Name="RssUrlTextBox" Text="https://lenta.ru/rss/news" PlaceholderText="Введите URL RSS-ленты"/>
        </StackPanel>
        
        <!-- Кнопки управления RSS -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Spacing="10" Margin="0,0,0,10">
            <Button Name="DownloadRssButton" 
                    Content="Загрузить RSS" 
                    Click="OnDownloadRss"
                    Width="150" Height="35"
                    FontSize="14"/>
            <Button Name="ParseRssButton" 
                    Content="Распарсить XML" 
                    Click="OnParseRss"
                    Width="150" Height="35"
                    FontSize="14"/>
            <TextBlock Name="StatusTextBlock" 
                       VerticalAlignment="Center" 
                       FontStyle="Italic"
                       Foreground="Gray"
                       Margin="10,0,0,0"/>
        </StackPanel>
        
        <!-- Полный XML текст -->
        <Border Grid.Row="2" BorderBrush="Gray" BorderThickness="1" Margin="0,0,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <TextBlock Grid.Row="0" 
                          Text="Полный текст RSS (XML):" 
                          FontWeight="Bold" 
                          Margin="5"
                          Background="#F0F0F0"/>
                
                <ScrollViewer Grid.Row="1" HorizontalScrollBarVisibility="Auto">
                    <TextBox Name="RawXmlTextBox" 
                             IsReadOnly="True" 
                             TextWrapping="Wrap" 
                             BorderThickness="0"
                             FontFamily="Consolas"
                             FontSize="11"
                             Padding="5"/>
                </ScrollViewer>
            </Grid>
        </Border>
        
        <!-- Распарсенные новости -->
        <Border Grid.Row="3" BorderBrush="Gray" BorderThickness="1" Margin="0,0,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <TextBlock Grid.Row="0" 
                          Text="Распарсенные новости:" 
                          FontWeight="Bold" 
                          Margin="5"
                          Background="#F0F0F0"/>
                
                <ListBox Grid.Row="1" Name="ParsedNewsListBox" Padding="5">
                    <ListBox.ItemTemplate>
                        <DataTemplate DataType="models:NewsItem">
                            <Border BorderBrush="#E0E0E0" 
                                    BorderThickness="0,0,0,1" 
                                    Padding="10" 
                                    Margin="0,0,0,5">
                                <StackPanel>
                                    <TextBlock Text="{Binding Title}" 
                                              FontWeight="Bold" 
                                              FontSize="14"
                                              TextWrapping="Wrap"
                                              Margin="0,0,0,5"/>
                                    <TextBlock Text="{Binding Description}" 
                                              TextWrapping="Wrap"
                                              Margin="0,0,0,5"
                                              Foreground="#555"/>
                                    <StackPanel Orientation="Horizontal" Spacing="15">
                                        <TextBlock Text="{Binding PubDate, StringFormat='Дата: {0:dd.MM.yyyy HH:mm}'}" 
                                                  FontSize="11" 
                                                  Foreground="Gray"/>
                                        <TextBlock Text="{Binding Link}" 
                                                  FontSize="11"
                                                  Foreground="Blue"
                                                  TextDecorations="Underline"
                                                  Cursor="Hand"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </Grid>
        </Border>
        
        <!-- Кнопки БД -->
        <StackPanel Grid.Row="4" Orientation="Horizontal" Spacing="10" Margin="0,0,0,10">
            <Button Name="SaveToDbButton" 
                    Content="Сохранить в БД" 
                    Click="OnSaveToDb"
                    Width="150" Height="35"
                    FontSize="14"/>
            <Button Name="LoadFromDbButton" 
                    Content="Загрузить из БД" 
                    Click="OnLoadFromDb"
                    Width="150" Height="35"
                    FontSize="14"/>
            <TextBlock Name="DbStatusTextBlock" 
                       VerticalAlignment="Center" 
                       FontStyle="Italic"
                       Foreground="Gray"
                       Margin="10,0,0,0"/>
        </StackPanel>
        
        <!-- Новости из БД -->
        <Border Grid.Row="5" BorderBrush="Gray" BorderThickness="1">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <TextBlock Grid.Row="0" 
                          Text="Новости из БД:" 
                          FontWeight="Bold" 
                          Margin="5"
                          Background="#F0F0F0"/>
                
                <ScrollViewer Grid.Row="1">
                    <TextBox Name="DbNewsTextBox" 
                             IsReadOnly="True" 
                             TextWrapping="Wrap" 
                             BorderThickness="0"
                             FontFamily="Consolas"
                             FontSize="11"
                             Padding="5"/>
                </ScrollViewer>
            </Grid>
        </Border>
    </Grid>
</Window>
```

### 7. Views/MainWindow.axaml.cs

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using RssReaderApp.Models;
using RssReaderApp.Services;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace RssReaderApp.Views
{
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
            
            // Проверка подключения к БД при запуске
            CheckDatabaseConnection();
        }
        
        private void CheckDatabaseConnection()
        {
            try
            {
                if (dbManager.TestConnection())
                {
                    dbManager.InitializeDatabase();
                    DbStatusTextBlock.Text = "БД подключена";
                    DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Green;
                }
                else
                {
                    DbStatusTextBlock.Text = "БД не подключена";
                    DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
                }
            }
            catch (Exception ex)
            {
                DbStatusTextBlock.Text = $"Ошибка БД: {ex.Message}";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
            }
        }
        
        private async void OnDownloadRss(object? sender, RoutedEventArgs e)
        {
            try
            {
                StatusTextBlock.Text = "Загрузка RSS...";
                StatusTextBlock.Foreground = Avalonia.Media.Brushes.Blue;
                
                DownloadRssButton.IsEnabled = false;
                
                // Установка URL из TextBox
                rssService.SetRssUrl(RssUrlTextBox.Text ?? "https://lenta.ru/rss/news");
                
                // Асинхронная загрузка
                currentXml = await Task.Run(() => rssService.DownloadRssFeed());
                
                RawXmlTextBox.Text = currentXml;
                
                StatusTextBlock.Text = "RSS загружен успешно";
                StatusTextBlock.Foreground = Avalonia.Media.Brushes.Green;
            }
            catch (Exception ex)
            {
                await ShowError("Ошибка загрузки RSS", ex.Message);
                StatusTextBlock.Text = $"Ошибка: {ex.Message}";
                StatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
            }
            finally
            {
                DownloadRssButton.IsEnabled = true;
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
                StatusTextBlock.Text = "Парсинг XML...";
                StatusTextBlock.Foreground = Avalonia.Media.Brushes.Blue;
                
                ParseRssButton.IsEnabled = false;
                
                currentNews = await Task.Run(() => xmlParser.ParseRss(currentXml));
                
                ParsedNewsListBox.ItemsSource = currentNews;
                
                StatusTextBlock.Text = $"Распарсено новостей: {currentNews.Count}";
                StatusTextBlock.Foreground = Avalonia.Media.Brushes.Green;
            }
            catch (Exception ex)
            {
                await ShowError("Ошибка парсинга XML", ex.Message);
                StatusTextBlock.Text = $"Ошибка парсинга: {ex.Message}";
                StatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
            }
            finally
            {
                ParseRssButton.IsEnabled = true;
            }
        }
        
        private async void OnSaveToDb(object? sender, RoutedEventArgs e)
        {
            if (currentNews == null || currentNews.Count == 0)
            {
                await ShowError("Ошибка", "Нет новостей для сохранения. Сначала загрузите и распарсите RSS");
                return;
            }
            
            try
            {
                DbStatusTextBlock.Text = "Сохранение в БД...";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Blue;
                
                SaveToDbButton.IsEnabled = false;
                
                await Task.Run(() => dbManager.SaveNews(currentNews));
                
                DbStatusTextBlock.Text = $"Сохранено новостей: {currentNews.Count}";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Green;
                
                await ShowInfo("Успех", $"Успешно сохранено {currentNews.Count} новостей в БД");
            }
            catch (Exception ex)
            {
                await ShowError("Ошибка сохранения в БД", ex.Message);
                DbStatusTextBlock.Text = $"Ошибка сохранения: {ex.Message}";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
            }
            finally
            {
                SaveToDbButton.IsEnabled = true;
            }
        }
        
        private async void OnLoadFromDb(object? sender, RoutedEventArgs e)
        {
            try
            {
                DbStatusTextBlock.Text = "Загрузка из БД...";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Blue;
                
                LoadFromDbButton.IsEnabled = false;
                
                var newsFromDb = await Task.Run(() => dbManager.LoadAllNews());
                
                var sb = new StringBuilder();
                sb.AppendLine($"=== ЗАГРУЖЕНО ИЗ БД: {newsFromDb.Count} НОВОСТЕЙ ===");
                sb.AppendLine();
                
                foreach (var news in newsFromDb)
                {
                    sb.AppendLine($"ID: {news.Id}");
                    sb.AppendLine($"Заголовок: {news.Title}");
                    sb.AppendLine($"Описание: {news.Description}");
                    sb.AppendLine($"Ссылка: {news.Link}");
                    sb.AppendLine($"Дата публикации: {news.PubDate:dd.MM.yyyy HH:mm}");
                    sb.AppendLine($"Добавлено в БД: {news.CreatedAt:dd.MM.yyyy HH:mm:ss}");
                    sb.AppendLine(new string('-', 80));
                    sb.AppendLine();
                }
                
                DbNewsTextBox.Text = sb.ToString();
                
                DbStatusTextBlock.Text = $"Загружено из БД: {newsFromDb.Count} новостей";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Green;
            }
            catch (Exception ex)
            {
                await ShowError("Ошибка загрузки из БД", ex.Message);
                DbStatusTextBlock.Text = $"Ошибка загрузки: {ex.Message}";
                DbStatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
            }
            finally
            {
                LoadFromDbButton.IsEnabled = true;
            }
        }
        
        private async Task ShowError(string title, string message)
        {
            var errorWindow = new Window
            {
                Title = title,
                Width = 400,
                Height = 200,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false
            };
            
            var panel = new StackPanel
            {
                Margin = new Avalonia.Thickness(20),
                Spacing = 15
            };
            
            panel.Children.Add(new TextBlock
            {
                Text = message,
                FontSize = 14,
                TextWrapping = Avalonia.Media.TextWrapping.Wrap
            });
            
            var okButton = new Button
            {
                Content = "OK",
                Width = 100,
                Height = 35,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center
            };
            okButton.Click += (s, e) => errorWindow.Close();
            panel.Children.Add(okButton);
            
            errorWindow.Content = panel;
            await errorWindow.ShowDialog(this);
        }
        
        private async Task ShowInfo(string title, string message)
        {
            var infoWindow = new Window
            {
                Title = title,
                Width = 400,
                Height = 180,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false
            };
            
            var panel = new StackPanel
            {
                Margin = new Avalonia.Thickness(20),
                Spacing = 15
            };
            
            panel.Children.Add(new TextBlock
            {
                Text = message,
                FontSize = 14,
                TextWrapping = Avalonia.Media.TextWrapping.Wrap,
                Foreground = Avalonia.Media.Brushes.Green
            });
            
            var okButton = new Button
            {
                Content = "OK",
                Width = 100,
                Height = 35,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center
            };
            okButton.Click += (s, e) => infoWindow.Close();
            panel.Children.Add(okButton);
            
            infoWindow.Content = panel;
            await infoWindow.ShowDialog(this);
        }
    }
}
```

---

## Инструкции по запуску

### Вариант 1: MySQL через Homebrew (быстрый)

```bash
# Установка MySQL
brew install mysql

# Запуск MySQL
brew services start mysql

# Создание БД и пользователя
mysql -u root -e "CREATE DATABASE IF NOT EXISTS rss_news CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -e "CREATE USER IF NOT EXISTS 'rss_user'@'localhost' IDENTIFIED BY 'rss_pass';"
mysql -u root -e "GRANT ALL PRIVILEGES ON rss_news.* TO 'rss_user'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Запуск приложения
cd 02C#/lab08/RssReaderApp
dotnet restore
dotnet build
dotnet run
```

### Вариант 2: MySQL через Docker

```bash
# Запуск MySQL контейнера
cd 02C#/lab08
docker compose up -d

# Ожидание запуска MySQL (около 30 секунд)
sleep 30

# Запуск приложения
cd RssReaderApp
dotnet restore
dotnet build
dotnet run
```

---

## Рекомендуемые скриншоты для отчета

1. **Скриншот кода:**
   - `RssService.cs` (использование `HttpWebRequest`)
   - `XmlParser.cs` (парсинг XML через `System.Xml`)
   - `DatabaseManager.cs` (работа с MySQL)
   - `MainWindow.axaml` (интерфейс)

2. **Скриншоты работы приложения:**
   - Загрузка RSS (полный XML в текстовом окне)
   - Распарсенные новости (красивый список с заголовками, описаниями, датами)
   - Сохранение в БД (сообщение об успехе)
   - Загрузка из БД (список новостей в текстовом окне)
   - Статусные сообщения (БД подключена, RSS загружен и т.д.)

3. **Скриншот структуры БД:**
   - Команда `DESCRIBE news;` в MySQL консоли
   - Результат `SELECT * FROM news LIMIT 5;`

---

## Вывод

В ходе выполнения лабораторной работы я успешно освоил ключевые технологии для создания сетевых приложений с базами данных на платформе .NET. Получил практический опыт работы с классами `HttpWebRequest` и `HttpWebResponse` из пространства имен `System.Net` для загрузки данных с веб-серверов. Понял принципы работы HTTP-протокола, необходимость указания UserAgent для корректной работы с некоторыми серверами и важность настройки таймаутов. Реализовал загрузку RSS-ленты новостей с сайта lenta.ru и вывел полный XML-контент в текстовое окно приложения.

Освоил работу с XML-документами через пространство имен `System.Xml`. Применил класс `XmlDocument` для парсинга XML-структуры, использовал метод `GetElementsByTagName` для извлечения элементов `<item>` и навигацию через `XmlNode` для доступа к вложенным элементам. Реализовал надежный парсинг дат в форматах RFC822 и RFC1123 с использованием `DateTime.TryParse` и `DateTime.TryParseExact`, что обеспечило корректную обработку временных меток из RSS-ленты.

Получил углубленные знания работы с реляционными базами данных MySQL на платформе C#. Использовал библиотеку `MySql.Data` и класс `MySqlConnection` для установки соединения с сервером БД. Реализовал класс `DatabaseManager`, который инкапсулирует всю логику работы с базой данных: создание таблицы через `CREATE TABLE IF NOT EXISTS`, удаление старых записей через `DELETE`, вставку новых данных через параметризованные запросы `INSERT` с использованием `MySqlParameter` для защиты от SQL-инъекций, и чтение данных через `SELECT` с помощью `MySqlDataReader`. Понял важность использования индексов для ускорения запросов и настройки кодировки utf8mb4 для корректной работы с кириллицей.

Создал полнофункциональное графическое приложение на базе кроссплатформенного UI-фреймворка Avalonia. Разработал сложную XAML-разметку интерфейса с использованием `Grid` для разделения окна на шесть функциональных зон: поле ввода URL, кнопки управления RSS, окно полного XML, список распарсенных новостей, кнопки управления БД и окно новостей из БД. Применил продвинутые возможности `ListBox` с кастомным `DataTemplate` и явным указанием `DataType="models:NewsItem"` для красивого отображения структурированных новостей с заголовками, описаниями и датами публикации.

Освоил асинхронное программирование в C# с помощью ключевых слов `async` и `await`. Применил метод `Task.Run` для выполнения долгих операций (сетевые запросы, парсинг XML, операции с БД) в фоновом потоке, что обеспечило отзывчивость пользовательского интерфейса. Понял, что использование `async`/`await` предотвращает блокировку UI-потока и позволяет пользователю продолжать взаимодействие с приложением во время выполнения длительных операций. Реализовал временное отключение кнопок через `IsEnabled = false` во время выполнения операций для предотвращения повторных вызовов.

Полученные навыки работы с сетевыми запросами, XML-парсингом, реляционными базами данных и асинхронным программированием являются фундаментальными для разработки современных приложений. Освоил полный цикл работы с внешними данными: загрузка через HTTP, парсинг структурированных форматов, сохранение в БД и представление в графическом интерфейсе. Эти знания станут основой для создания более сложных систем: веб-сервисов, REST API клиентов, систем агрегации данных и enterprise-приложений на платформе .NET.
