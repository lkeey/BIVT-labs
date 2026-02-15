namespace Level1;

/// <summary>
/// Задача 10: Возвести число 3 в 7-ю степень без операции возведения в степень
/// </summary>
public static class Task10
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 10: Возведение 3 в 7-ю степень ===\n");
        
        int result = 1;
        int baseNum = 3;
        int power = 7;
        
        Console.Write($"{baseNum}^{power} = ");
        
        for (int i = 0; i < power; i++)
        {
            result *= baseNum;
            Console.Write($"{baseNum}");
            if (i < power - 1) Console.Write(" × ");
        }
        
        Console.WriteLine($" = {result}");
    }
}
