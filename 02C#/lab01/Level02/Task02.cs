namespace Level2;

/// <summary>
/// Задача 2: Определить наибольшее значение n, для которого
/// произведение p = 1·4·7·...·n не превышает L = 30000
/// </summary>
public static class Task02
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 2: Произведение с ограничением L = 30000 ===\n");
        
        const int L = 30000;
        int product = 1;
        int n = 1;
        
        Console.WriteLine($"Ограничение L = {L}\n");
        
        while (product * n <= L)
        {
            product *= n;
            Console.WriteLine($"n={n,2}: произведение = {product,6}");
            n += 3;
        }
        
        n -= 3; // возврат к последнему подходящему значению
        
        Console.WriteLine($"\nНаибольшее значение n = {n}");
        Console.WriteLine($"Произведение p = {product}");
        Console.WriteLine($"Следующий член (n+3={n+3}) даст произведение {product * (n + 3)}, что больше {L}");
    }
}
