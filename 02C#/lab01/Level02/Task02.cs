namespace Level2;

/// <summary>
/// Задача 2: Определить наибольшее значение n, для которого
/// произведение p = 1·4·7·...·n не превышает L = 30000
/// </summary>
public static class Task02
{
    public static void Execute()
    {
        
        const int L = 30000;
        int product = 1;
        int n = 1;
                
        while (product * n <= L)
        {
            product *= n;
            n += 3;
        }
        
        n -= 3; // возврат к последнему подходящему значению
        
        Console.WriteLine($"\nНаибольшее значение n = {n}");
        Console.WriteLine($"Произведение p = {product}");
    }
}
