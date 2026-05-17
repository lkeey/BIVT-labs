using System;
using System.Collections.ObjectModel;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using AdsBoardApp.Models;
using AdsBoardApp.Services;

namespace AdsBoardApp.Views;

public partial class MainWindow : Window
{
    private readonly MulticastService service = new();
    private readonly ObservableCollection<AdItem> ads = new();

    public MainWindow()
    {
        InitializeComponent();

        AdsListBox.ItemsSource = ads;

        service.AdReceived += OnAdReceived;
        service.SystemReceived += OnSystemReceived;
        service.PrivateMessageReceived += OnPrivateMessageReceived;

        Closing += OnWindowClosing;
    }

    private void OnLogin(object? sender, RoutedEventArgs e)
    {
        string name = (UserNameTextBox.Text ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            StatusTextBlock.Text = "Введите имя пользователя";
            StatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
            return;
        }

        try
        {
            service.Login(name);
            UserNameTextBox.IsEnabled = false;
            LoginButton.IsEnabled = false;
            LogoutButton.IsEnabled = true;
            PublishButton.IsEnabled = true;
            StatusTextBlock.Text = $"В сети как «{name}» (chatPort={service.ChatPort})";
            StatusTextBlock.Foreground = Avalonia.Media.Brushes.Green;
        }
        catch (Exception ex)
        {
            StatusTextBlock.Text = $"Ошибка входа: {ex.Message}";
            StatusTextBlock.Foreground = Avalonia.Media.Brushes.Red;
        }
    }

    private void OnLogout(object? sender, RoutedEventArgs e)
    {
        service.Logout();
        ResetUiToOffline();
    }

    private void ResetUiToOffline()
    {
        UserNameTextBox.IsEnabled = true;
        LoginButton.IsEnabled = true;
        LogoutButton.IsEnabled = false;
        PublishButton.IsEnabled = false;
        WriteSellerButton.IsEnabled = false;
        StatusTextBlock.Text = "Не подключено";
        StatusTextBlock.Foreground = Avalonia.Media.Brushes.Gray;
    }

    private void OnPublish(object? sender, RoutedEventArgs e)
    {
        string title = (TitleTextBox.Text ?? string.Empty).Trim();
        string price = (PriceTextBox.Text ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(title) || string.IsNullOrWhiteSpace(price)) return;

        service.PublishAd(title, price);

        TitleTextBox.Text = string.Empty;
        PriceTextBox.Text = string.Empty;
    }

    private void OnAdReceived(string time, string seller, string title, string price)
    {
        Dispatcher.UIThread.Post(() =>
        {
            ads.Insert(0, new AdItem
            {
                Display = $"[{time}] {seller}: {title} – {price} руб.",
                Seller = seller,
            });
        });
    }

    private void OnSystemReceived(string text)
    {
        Dispatcher.UIThread.Post(() =>
        {
            ads.Insert(0, new AdItem
            {
                Display = $"→ {text}",
                Seller = null,
            });
        });
    }

    private void OnPrivateMessageReceived(string sender, string text)
    {
        Dispatcher.UIThread.Post(async () =>
        {
            await ShowInfo($"Сообщение от {sender}", text);
        });
    }

    private void OnAdSelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        WriteSellerButton.IsEnabled = service.IsOnline
            && AdsListBox.SelectedItem is AdItem item
            && !string.IsNullOrEmpty(item.Seller)
            && item.Seller != service.UserName;
    }

    private async void OnWriteSeller(object? sender, RoutedEventArgs e)
    {
        if (AdsListBox.SelectedItem is not AdItem item || string.IsNullOrEmpty(item.Seller)) return;

        var dialog = new WriteToSellerWindow(item.Seller);
        var text = await dialog.ShowDialog<string?>(this);
        if (string.IsNullOrWhiteSpace(text)) return;

        bool sent = service.SendPrivateMessage(item.Seller, text);
        if (!sent)
        {
            await ShowInfo("Не удалось отправить", $"Контакт продавца «{item.Seller}» не найден. Дождитесь его следующего объявления.");
        }
    }

    private void OnWindowClosing(object? sender, WindowClosingEventArgs e)
    {
        if (service.IsOnline)
        {
            service.Logout();
        }
    }

    private async System.Threading.Tasks.Task ShowInfo(string title, string message)
    {
        var infoWindow = new Window
        {
            Title = title,
            Width = 420,
            Height = 200,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false,
        };

        var panel = new StackPanel
        {
            Margin = new Avalonia.Thickness(20),
            Spacing = 15,
        };

        panel.Children.Add(new TextBlock
        {
            Text = message,
            FontSize = 14,
            TextWrapping = Avalonia.Media.TextWrapping.Wrap,
        });

        var okButton = new Button
        {
            Content = "OK",
            Width = 100,
            Height = 32,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
        };
        okButton.Click += (_, _) => infoWindow.Close();
        panel.Children.Add(okButton);

        infoWindow.Content = panel;
        await infoWindow.ShowDialog(this);
    }
}
