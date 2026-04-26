using Avalonia.Controls;
using Avalonia.Interactivity;
using System;

namespace BankAccountGUI.Views
{
    public partial class MainWindow : Window
    {
        private Account account = new Account();
        private Currency[] currencies = new Currency[]
        {
            new Currency("RUR", 1.0),
            new Currency("INR", 0.90),
            new Currency("USD", 95.0)
        };

        public MainWindow()
        {
            InitializeComponent();
        }

        private void OnDisplayCurrencyChanged(object? sender, SelectionChangedEventArgs e)
        {
            if (DisplayCurrencyCombo == null || BalanceLabel == null) return;
            UpdateBalance();
        }

        private void OnDepositClick(object? sender, RoutedEventArgs e)
        {
            if (!double.TryParse(AmountTextBox.Text, out double amount) || amount <= 0)
            {
                MessageLabel.Text = "Ошибка: введите положительное число";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Red;
                return;
            }

            int currIndex = TransactionCurrencyCombo.SelectedIndex;
            Currency currency = currencies[currIndex];

            if (account.Deposit(amount, currency))
            {
                MessageLabel.Text = $"Успешно зачислено: {amount:F2} {currency.Code}";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Green;
                AmountTextBox.Text = "";
                UpdateBalance();
            }
            else
            {
                MessageLabel.Text = "Ошибка при зачислении";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Red;
            }
        }

        private void OnWithdrawClick(object? sender, RoutedEventArgs e)
        {
            if (!double.TryParse(AmountTextBox.Text, out double amount) || amount <= 0)
            {
                MessageLabel.Text = "Ошибка: введите положительное число";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Red;
                return;
            }

            int currIndex = TransactionCurrencyCombo.SelectedIndex;
            Currency currency = currencies[currIndex];

            double availableBalance = account.GetBalanceInCurrency(currency);
            if (amount > availableBalance)
            {
                MessageLabel.Text = $"Ошибка: недостаточно средств. Доступно: {availableBalance:F2} {currency.Code}";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Red;
                return;
            }

            if (account.Withdraw(amount, currency))
            {
                MessageLabel.Text = $"Успешно снято: {amount:F2} {currency.Code}";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Green;
                AmountTextBox.Text = "";
                UpdateBalance();
            }
            else
            {
                MessageLabel.Text = "Ошибка при снятии средств";
                MessageLabel.Foreground = Avalonia.Media.Brushes.Red;
            }
        }

        private void UpdateBalance()
        {
            if (DisplayCurrencyCombo == null || BalanceLabel == null) return;
            
            int displayIndex = DisplayCurrencyCombo.SelectedIndex;
            Currency displayCurrency = currencies[displayIndex];
            double balance = account.GetBalanceInCurrency(displayCurrency);
            BalanceLabel.Text = $"Текущий баланс: {balance:F2} {displayCurrency.Code}";
        }
    }
}
