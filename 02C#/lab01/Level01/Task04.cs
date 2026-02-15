namespace Level1;

/// <summary>
/// Задача 4: Вычислить s = cos x + (cos 2x)/x + (cos 3x)/x² + ... + (cos 9x)/x⁸
/// </summary>
public static class Task04
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 4: s = cos x + (cos 2x)/x + (cos 3x)/x² + ... + (cos 9x)/x⁸ ===\n");
        
        Console.Write("Введите значение x: ");
        double x = double.Parse(Console.ReadLine() ?? "2.0");
        
        double sum = 0;
        double xPower = 1; // x^0 = 1
        
        for (int i = 1; i <= 9; i++)
        {
            double term = Math.Cos(i * x) / xPower;
            sum += term;
            Console.WriteLine($"cos({i}x)/x^{i-1} = {term:f4}");
            xPower *= x;
        }
        
        Console.WriteLine($"\nПри x = {x:f2}, сумма s = {sum:f4}");
    }
}
