using System;

namespace BankAccount
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.OutputEncoding = System.Text.Encoding.UTF8;

            Currency[] currencies = new Currency[]
            {
                new Currency("RUR", 1.0),
                new Currency("INR", 0.90),
                new Currency("USD", 95.0)
            };

            Account account = new Account();

            int displayCurrencyIndex = 0;

            Console.WriteLine("===========================================");
            Console.WriteLine("  БАНКОВСКИЙ СЧЕТ - ЛАБОРАТОРНАЯ РАБОТА №4");
            Console.WriteLine("===========================================");
            Console.WriteLine();
            Console.WriteLine("Валюты:");
            for (int i = 0; i < currencies.Length; i++)
            {
                Console.WriteLine($"  {i + 1}. {currencies[i]}");
            }
            Console.WriteLine();

            while (true)
            {
                Console.WriteLine();
                Console.WriteLine("==========================================");
                Console.WriteLine("СОСТОЯНИЕ СЧЕТА");
                Console.WriteLine("==========================================");
                Currency displayCurrency = currencies[displayCurrencyIndex];
                double displayBalance = account.GetBalanceInCurrency(displayCurrency);
                Console.WriteLine($"Текущий баланс: {displayBalance:F2} {displayCurrency.Code}");
                Console.WriteLine($"Валюта отображения: {displayCurrency.Code}");
                Console.WriteLine();

                Console.WriteLine("==========================================");
                Console.WriteLine("МЕНЮ");
                Console.WriteLine("==========================================");
                Console.WriteLine("1. Зачислить средства");
                Console.WriteLine("2. Снять средства");
                Console.WriteLine("3. Сменить валюту отображения");
                Console.WriteLine("0. Выход");
                Console.WriteLine();
                Console.Write("Выберите действие: ");

                string choice = Console.ReadLine();
                Console.WriteLine();

                switch (choice)
                {
                    case "1":
                        Deposit(account, currencies);
                        break;
                    case "2":
                        Withdraw(account, currencies);
                        break;
                    case "3":
                        displayCurrencyIndex = ChangeCurrency(currencies, displayCurrencyIndex);
                        break;
                    case "0":
                        Console.WriteLine("Программа завершена.");
                        return;
                    default:
                        Console.WriteLine("Неверный выбор. Попробуйте снова.");
                        break;
                }
            }
        }

        static void Deposit(Account account, Currency[] currencies)
        {
            Console.WriteLine("==========================================");
            Console.WriteLine("ТРАНЗАКЦИЯ: ЗАЧИСЛЕНИЕ");
            Console.WriteLine("==========================================");

            int currencyIndex = SelectCurrency(currencies);
            if (currencyIndex == -1) return;

            Currency currency = currencies[currencyIndex];

            Console.Write($"Введите сумму для зачисления ({currency.Code}): ");
            string input = Console.ReadLine();

            if (!double.TryParse(input, out double amount) || amount <= 0)
            {
                Console.WriteLine("Ошибка: введите положительное число.");
                return;
            }

            if (account.Deposit(amount, currency))
            {
                Console.WriteLine($"Успешно зачислено: {amount:F2} {currency.Code}");
                double newBalance = account.GetBalanceInCurrency(currency);
                Console.WriteLine($"Новый баланс: {newBalance:F2} {currency.Code}");
            }
            else
            {
                Console.WriteLine("Ошибка при зачислении.");
            }
        }

        static void Withdraw(Account account, Currency[] currencies)
        {
            Console.WriteLine("==========================================");
            Console.WriteLine("ТРАНЗАКЦИЯ: СНЯТИЕ");
            Console.WriteLine("==========================================");

            int currencyIndex = SelectCurrency(currencies);
            if (currencyIndex == -1) return;

            Currency currency = currencies[currencyIndex];

            Console.Write($"Введите сумму для снятия ({currency.Code}): ");
            string input = Console.ReadLine();

            if (!double.TryParse(input, out double amount) || amount <= 0)
            {
                Console.WriteLine("Ошибка: введите положительное число.");
                return;
            }

            double availableBalance = account.GetBalanceInCurrency(currency);
            if (amount > availableBalance)
            {
                Console.WriteLine($"Ошибка: недостаточно средств.");
                Console.WriteLine($"Доступно: {availableBalance:F2} {currency.Code}");
                return;
            }

            if (account.Withdraw(amount, currency))
            {
                Console.WriteLine($"Успешно снято: {amount:F2} {currency.Code}");
                double newBalance = account.GetBalanceInCurrency(currency);
                Console.WriteLine($"Новый баланс: {newBalance:F2} {currency.Code}");
            }
            else
            {
                Console.WriteLine("Ошибка при снятии.");
            }
        }

        static int SelectCurrency(Currency[] currencies)
        {
            Console.WriteLine("Выберите валюту транзакции:");
            for (int i = 0; i < currencies.Length; i++)
            {
                Console.WriteLine($"  {i + 1}. {currencies[i].Code}");
            }
            Console.Write("Ваш выбор: ");

            string input = Console.ReadLine();
            if (int.TryParse(input, out int choice) && choice >= 1 && choice <= currencies.Length)
            {
                return choice - 1;
            }

            Console.WriteLine("Неверный выбор валюты.");
            return -1;
        }

        static int ChangeCurrency(Currency[] currencies, int currentIndex)
        {
            Console.WriteLine("==========================================");
            Console.WriteLine("СМЕНА ВАЛЮТЫ ОТОБРАЖЕНИЯ");
            Console.WriteLine("==========================================");
            Console.WriteLine("Доступные валюты:");
            for (int i = 0; i < currencies.Length; i++)
            {
                string marker = (i == currentIndex) ? " (текущая)" : "";
                Console.WriteLine($"  {i + 1}. {currencies[i].Code}{marker}");
            }
            Console.Write("Выберите валюту: ");

            string input = Console.ReadLine();
            if (int.TryParse(input, out int choice) && choice >= 1 && choice <= currencies.Length)
            {
                Console.WriteLine($"Валюта отображения изменена на {currencies[choice - 1].Code}");
                return choice - 1;
            }

            Console.WriteLine("Неверный выбор. Валюта не изменена.");
            return currentIndex;
        }
    }
}
