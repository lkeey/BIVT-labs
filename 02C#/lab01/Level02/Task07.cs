namespace Level2;

/// <summary>
/// Задача 7: Спортсмен начал с 10 км, каждый день увеличивает на 10% от предыдущего
/// а) Какой суммарный путь за 7 дней?
/// б) Через сколько дней суммарный путь = 100 км?
/// в) Через сколько дней дневная норма > 20 км?
/// </summary>
public static class Task07
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 7: Тренировки спортсмена ===\n");
        
        // Подзадача а)
        Console.WriteLine("а) Суммарный путь за 7 дней:\n");
        double dailyDistance = 10.0;
        double totalDistance = 0;
        
        for (int day = 1; day <= 7; day++)
        {
            totalDistance += dailyDistance;
            Console.WriteLine($"День {day}: {dailyDistance,6:f2} км, всего: {totalDistance,7:f2} км");
            dailyDistance *= 1.1;
        }
        
        Console.WriteLine($"\nОтвет а): За 7 дней спортсмен пробежит {totalDistance:f2} км\n");
        
        // Подзадача б)
        Console.WriteLine("б) Через сколько дней суммарный путь достигнет 100 км?\n");
        dailyDistance = 10.0;
        totalDistance = 0;
        int days = 0;
        
        while (totalDistance < 100.0)
        {
            days++;
            totalDistance += dailyDistance;
            Console.WriteLine($"День {days}: +{dailyDistance,6:f2} км, всего: {totalDistance,7:f2} км");
            dailyDistance *= 1.1;
        }
        
        Console.WriteLine($"\nОтвет б): Через {days} дней суммарный путь составит {totalDistance:f2} км\n");
        
        // Подзадача в)
        Console.WriteLine("в) Через сколько дней дневная норма превысит 20 км?\n");
        dailyDistance = 10.0;
        days = 0;
        
        while (dailyDistance <= 20.0)
        {
            days++;
            dailyDistance *= 1.1;
            Console.WriteLine($"День {days}: {dailyDistance,6:f2} км");
        }
        
        Console.WriteLine($"\nОтвет в): На {days}-й день спортсмен впервые пробежит больше 20 км ({dailyDistance:f2} км)");
    }
}
