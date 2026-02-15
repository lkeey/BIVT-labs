namespace Level1;

/// <summary>
/// Задача 5: Сумма квадратов 10 членов арифметической прогрессии
/// s = p² + (p + h)² + ... + (p + 9h)²
/// </summary>
public static class Task05
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 5: Сумма квадратов арифметической прогрессии ===\n");
        
        Console.Write("Введите начальное значение p: ");
        double p = double.Parse(Console.ReadLine() ?? "2.0");
        
        Console.Write("Введите шаг h: ");
        double h = double.Parse(Console.ReadLine() ?? "1.5");
        
        double sum = 0;
        
        for (int i = 0; i < 10; i++)
        {
            double member = p + i * h;
            double square = member * member;
            sum += square;
            Console.WriteLine($"({member:f2})² = {square:f2}");
        }
        
        Console.WriteLine($"\nСумма s = {sum:f2}");
    }
}
