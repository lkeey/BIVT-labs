namespace Level1;

/// <summary>
/// Задача 2: Вычислить s = 1 + 1/2 + 1/3 + 1/4 + ... + 1/10 (гармонический ряд)
/// </summary>
public static class Task02
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 2: Гармонический ряд s = 1 + 1/2 + 1/3 + ... + 1/10 ===\n");
        
        double sum = 0;
        for (int i = 1; i <= 10; i++)
        {
            double term = 1.0 / i;
            sum += term;
            Console.WriteLine($"1/{i} = {term:f4}");
        }
        
        Console.WriteLine($"\nСумма s = {sum:f4}");
    }
}
