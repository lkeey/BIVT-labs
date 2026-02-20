namespace Level1;

/// <summary>
/// Задача 14: Напечатать 8 первых членов последовательности Фибоначчи
/// Первые два числа равны 1, каждое последующее - сумма двух предыдущих
/// </summary>
public static class Task14
{
    public static void Execute()
    {        
        int fib1 = 1, fib2 = 1;
        
        Console.Write($"{fib1} {fib2} ");
        
        for (int i = 3; i <= 8; i++)
        {
            int fibNext = fib1 + fib2;
            Console.Write($"{fibNext} ");
            fib1 = fib2;
            fib2 = fibNext;
        }
        
        Console.WriteLine();
    }
}
