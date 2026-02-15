namespace Level2;

/// <summary>
/// Задача 9: Определить, сколько раз нужно разрезать пополам нить длиной L = 0.1 м,
/// чтобы длина уменьшилась до атома (размер атома = 10⁻¹⁰ м)
/// </summary>
public static class Task09
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 9: Разрезание нити до атомного размера ===\n");
        
        double length = 0.1; // 0.1 м = 10 см
        const double atomSize = 1e-10; // 10⁻¹⁰ м
        int cuts = 0;
        
        Console.WriteLine($"Начальная длина нити: {length} м");
        Console.WriteLine($"Размер атома: {atomSize:E2} м\n");
        Console.WriteLine("Разрез\tДлина (м)");
        Console.WriteLine("────────────────────────");
        Console.WriteLine($"{cuts,4}\t{length:E6}");
        
        while (length > atomSize)
        {
            cuts++;
            length /= 2;
            
            if (cuts <= 10 || cuts % 5 == 0 || length <= atomSize)
            {
                Console.WriteLine($"{cuts,4}\t{length:E6}");
            }
        }
        
        Console.WriteLine($"\nНеобходимо разрезать {cuts} раз");
        Console.WriteLine($"Конечная длина: {length:E6} м");
    }
}
