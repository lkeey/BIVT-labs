namespace Level3;

/// <summary>
/// Задача 7: Вычислить сумму ряда s = Σ(x^(2i) / (2i)!) для (e^x - e^(-x)) / 2
/// a = 0.1, b = 1, h = 0.05, eps = 0.0001
/// </summary>
public static class Task07
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 7: Ряд для (e^x - e^(-x)) / 2 = sh(x) ===\n");
        
        const double a = 0.1, b = 1.0, h = 0.05;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = x; // первый член при i=0: x^1/1! = x
            double term = x;
            int i = 1;
            
            do
            {
                term *= x * x / ((2 * i) * (2 * i + 1));
                s += term;
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = (Math.Exp(x) - Math.Exp(-x)) / 2.0;
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
