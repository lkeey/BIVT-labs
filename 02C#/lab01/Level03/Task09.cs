namespace Level3;

/// <summary>
/// Задача 9: Вычислить сумму ряда s = Σ((-1)^i · x^(2i+1) / (2i+1)) для arctg(x)
/// a = 0.1, b = 0.5, h = 0.05, eps = 0.0001
/// </summary>
public static class Task09
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 9: Ряд для arctg(x) ===\n");
        
        const double a = 0.1, b = 0.5, h = 0.05;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │ y = arctg(x) │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = x; // первый член при i=0: x
            double term = x;
            int i = 1;
            
            do
            {
                term *= -x * x * (2 * i - 1) / (2 * i + 1);
                s += term;
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = Math.Atan(x);
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
