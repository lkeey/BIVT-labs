using Avalonia.Controls;
using Avalonia.Interactivity;

namespace AdsBoardApp.Views;

public partial class WriteToSellerWindow : Window
{
    public WriteToSellerWindow()
    {
        InitializeComponent();
    }

    public WriteToSellerWindow(string sellerName) : this()
    {
        Title = $"Сообщение для {sellerName}";
        HeaderTextBlock.Text = $"Личное сообщение продавцу: {sellerName}";
    }

    private void OnSend(object? sender, RoutedEventArgs e)
    {
        Close(MessageTextBox.Text);
    }

    private void OnCancel(object? sender, RoutedEventArgs e)
    {
        Close(null);
    }
}
