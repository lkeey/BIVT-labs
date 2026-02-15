namespace Level1;

/// <summary>
/// Задача 17: Определить расстояние до линии горизонта с высоты 1, 2, ..., 10 км
/// Формула: d = sqrt(2 * R * h), где R ≈ 6350 км - радиус Земли, h - высота
/// </summary>
public static class Task17
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 17: Расстояние до горизонта с высоты ===\n");
        
        const double R = 6350.0; // радиус Земли в км
        
        Console.WriteLine("Высота (км)\tРасстояние до горизонта (км)");
        Console.WriteLine("───────────────────────────────────────────");
        
        for (int h = 1; h <= 10; h++)
        {
            double distance = Math.Sqrt(2 * R * h);
            Console.WriteLine($"{h,6}\t\t{distance,10:f2}");
        }
    }
}
