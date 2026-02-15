namespace Level3;

/// <summary>
/// Задача 1: Вычислить сумму ряда s = Σ((-1)^i · x^(2i) / (2i)!) для cos(x)
/// a = 0.1, b = 1, h = 0.1, eps = 0.0001
/// Сравнить с y = cos(x)
/// </summary>
public static class Task01
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 1: Ряд для cos(x) ===\n");
        
        const double a = 0.1, b = 1.0, h = 0.1;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │   y = cos(x) │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 1.0; // первый член ряда
            double term = 1.0;
            int i = 1;
            
            // Вычисление суммы ряда с рекуррентным соотношением
            do
            {
                term *= -x * x / ((2 * i - 1) * (2 * i));
                s += term;
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = Math.Cos(x);
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
