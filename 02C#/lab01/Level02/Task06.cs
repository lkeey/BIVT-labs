namespace Level2;

/// <summary>
/// Задача 6: Определить, через какое время в замкнутом объеме будет 10⁵ клеток
/// Начальное количество: 10 клеток, амеба делится каждые 3 часа
/// </summary>
public static class Task06
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 6: Размножение амеб до 10⁵ клеток ===\n");
        
        const int targetCells = 100000;
        int cells = 10;
        int hours = 0;
        
        Console.WriteLine($"Начальное количество клеток: {cells}");
        Console.WriteLine($"Целевое количество клеток: {targetCells:N0}\n");
        Console.WriteLine("Время (часы)\tКоличество клеток");
        Console.WriteLine("─────────────────────────────────────");
        Console.WriteLine($"{hours,6}\t\t{cells,15:N0}");
        
        while (cells < targetCells)
        {
            hours += 3;
            cells *= 2;
            Console.WriteLine($"{hours,6}\t\t{cells,15:N0}");
        }
        
        Console.WriteLine($"\nЧерез {hours} часов будет {cells:N0} клеток");
    }
}
