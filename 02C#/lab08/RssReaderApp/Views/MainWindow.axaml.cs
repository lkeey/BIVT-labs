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
                    DbStatusTextBlock.Text = "БД не подключена. Запустите: docker compose up -d";
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
