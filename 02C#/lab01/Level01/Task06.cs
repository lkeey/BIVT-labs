namespace Level1;

/// <summary>
/// Задача 6: Табулирование функции y = 0.5x² - 7x на отрезке [-4, 4] с шагом 0.5
/// </summary>
public static class Task06
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 6: Табулирование функции y = 0.5x² - 7x ===\n");
        Console.WriteLine("x\t\ty");
        Console.WriteLine("─────────────────");
        
        for (double x = -4.0; x <= 4.0 + 0.0001; x += 0.5)
        {
            double y = 0.5 * x * x - 7 * x;
            Console.WriteLine($"{x,6:f1}\t\t{y,8:f2}");
        }
    }
}
