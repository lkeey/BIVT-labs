namespace Level1;

/// <summary>
/// Задача 1: Вычислить s = 2 + 5 + 8 + ... + 35 (арифметическая прогрессия)
/// </summary>
public static class Task01
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 1: Сумма арифметической прогрессии 2 + 5 + 8 + ... + 35 ===\n");
        
        int sum = 0;
        for (int i = 2; i <= 35; i += 3)
        {
            sum += i;
            Console.Write($"{i} ");
        }
        
        Console.WriteLine($"\n\nСумма s = {sum}");
    }
}
