namespace Level2;

/// <summary>
/// Задача 8: Вкладчик положил 10000 рублей под 8% в месяц
/// Определить, через какое время сумма удвоится
/// </summary>
public static class Task08
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 8: Вклад в банке ===\n");
        
        double initialAmount = 10000.0;
        double amount = initialAmount;
        double targetAmount = initialAmount * 2;
        double interestRate = 0.08; // 8% в месяц
        int months = 0;
        
        Console.WriteLine($"Начальная сумма: {initialAmount:N2} руб.");
        Console.WriteLine($"Процентная ставка: {interestRate * 100}% в месяц");
        Console.WriteLine($"Целевая сумма: {targetAmount:N2} руб.\n");
        Console.WriteLine("Месяц\tСумма (руб.)");
        Console.WriteLine("─────────────────────────");
        Console.WriteLine($"{months,3}\t{amount,12:N2}");
        
        while (amount < targetAmount)
        {
            months++;
            amount *= (1 + interestRate);
            Console.WriteLine($"{months,3}\t{amount,12:N2}");
        }
        
        Console.WriteLine($"\nСумма удвоится через {months} месяцев");
        Console.WriteLine($"Итоговая сумма: {amount:N2} руб.");
    }
}
