namespace Level1;

/// <summary>
/// Задача 18: Амеба каждые 3 часа делится на 2 клетки
/// Определить количество клеток через 3, 6, 9, ..., 24 часа
/// Начальное количество: 10 клеток
/// </summary>
public static class Task18
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 18: Размножение амеб ===\n");
        
        int cells = 10;
        
        Console.WriteLine("Время (часы)\tКоличество клеток");
        Console.WriteLine("─────────────────────────────────");
        Console.WriteLine($"{0,6}\t\t{cells,10}");
        
        for (int hours = 3; hours <= 24; hours += 3)
        {
            cells *= 2;
            Console.WriteLine($"{hours,6}\t\t{cells,10}");
        }
    }
}
