namespace Level1;

/// <summary>
/// Задача 7: Вычислить 6! (факториал числа 6)
/// </summary>
public static class Task07
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 7: Вычислить 6! ===\n");
        
        int factorial = 1;
        Console.Write("6! = ");
        
        for (int i = 1; i <= 6; i++)
        {
            factorial *= i;
            Console.Write(i);
            if (i < 6) Console.Write(" × ");
        }
        
        Console.WriteLine($" = {factorial}");
    }
}
