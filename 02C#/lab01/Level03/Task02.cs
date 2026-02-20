namespace Level3;

/// <summary>
/// Задача 2: Вычислить сумму ряда s = Σ(x^i · sin(iπ/4))
/// a = 0.1, b = 0.8, h = 0.1
/// Сравнить с y = (x·sin(π/4)) / (1 - 2x·cos(π/4) + x²)
/// </summary>
public static class Task02
{
    public static void Execute()
    {        
        const double a = 0.1, b = 0.8, h = 0.1;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 0;
            const int maxTerms = 18;
            
            for (int i = 1; i <= maxTerms; i++)
            {
                double term = Math.Pow(x, i) * Math.Sin(i * Math.PI / 4);
                s += term;
            }
            
            double cosPi4 = Math.Cos(Math.PI / 4);
            double sinPi4 = Math.Sin(Math.PI / 4);
            double y = (x * sinPi4) / (1 - 2 * x * cosPi4 + x * x);
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {maxTerms,3}");
        }
    }
}
