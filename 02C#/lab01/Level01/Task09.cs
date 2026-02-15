namespace Level1;

/// <summary>
/// Задача 9: Вычислить s = (-1)¹·5¹/1! + (-1)²·5²/2! + ... + (-1)⁶·5⁶/6!
/// </summary>
public static class Task09
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 9: Знакопеременный ряд с факториалами ===\n");
        
        double sum = 0;
        int factorial = 1;
        int sign = -1;
        int power = 5;
        
        for (int i = 1; i <= 6; i++)
        {
            factorial *= i;
            double term = sign * power / (double)factorial;
            sum += term;
            
            Console.WriteLine($"(-1)^{i} × 5^{i} / {i}! = {term:f6}");
            
            sign *= -1;
            power *= 5;
        }
        
        Console.WriteLine($"\nСумма s = {sum:f6}");
    }
}
