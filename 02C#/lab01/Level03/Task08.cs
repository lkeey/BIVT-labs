namespace Level3;

/// <summary>
/// Задача 8: Вычислить сумму ряда s = Σ(x^i / i!) для e^x
/// a = 0.1, b = 1, h = 0.05, eps = 0.0001
/// </summary>
public static class Task08
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 8: Ряд для e^x ===\n");
        
        const double a = 0.1, b = 1.0, h = 0.05;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │   y = e^x    │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 1.0; // первый член: x^0/0! = 1
            double term = 1.0;
            int i = 1;
            
            do
            {
                term *= x / i;
                s += term;
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = Math.Exp(x);
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
