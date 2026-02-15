namespace Level1;

/// <summary>
/// Задача 8: Вычислить s = 1! + 2! + ... + 6!
/// </summary>
public static class Task08
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 8: Сумма факториалов s = 1! + 2! + ... + 6! ===\n");
        
        int sum = 0;
        int factorial = 1;
        
        for (int i = 1; i <= 6; i++)
        {
            factorial *= i;
            sum += factorial;
            Console.WriteLine($"{i}! = {factorial}");
        }
        
        Console.WriteLine($"\nСумма s = {sum}");
    }
}
