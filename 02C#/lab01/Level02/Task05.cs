namespace Level2;

/// <summary>
/// Задача 5: Определить частное и остаток от деления двух целых чисел N и M
/// Использовать только операцию вычитания
/// </summary>
public static class Task05
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 5: Деление через вычитание ===\n");
        
        Console.Write("Введите делимое N: ");
        int N = int.Parse(Console.ReadLine() ?? "25");
        
        Console.Write("Введите делитель M: ");
        int M = int.Parse(Console.ReadLine() ?? "7");
        
        if (M == 0)
        {
            Console.WriteLine("Ошибка: деление на ноль!");
            return;
        }
        
        int quotient = 0;  // частное
        int remainder = Math.Abs(N);  // остаток (работаем с модулем)
        int divisor = Math.Abs(M);
        
        Console.WriteLine($"\nДелим {N} на {M}:\n");
        
        while (remainder >= divisor)
        {
            remainder -= divisor;
            quotient++;
            Console.WriteLine($"Шаг {quotient}: остаток = {remainder}");
        }
        
        // Учитываем знаки
        if ((N < 0) ^ (M < 0)) // XOR - если знаки разные
        {
            quotient = -quotient;
        }
        
        if (N < 0)
        {
            remainder = -remainder;
        }
        
        Console.WriteLine($"\nЧастное: {quotient}");
        Console.WriteLine($"Остаток: {remainder}");
        Console.WriteLine($"\nПроверка: {M} × {quotient} + {remainder} = {M * quotient + remainder}");
    }
}
