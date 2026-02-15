namespace Level3;

/// <summary>
/// Задача 4: Вычислить сумму ряда s = Σ((2i-1)·x^(2i) / (2i)!) для (1+2x²)e^(x²)
/// a = 0.1, b = 1, h = 0.1, eps = 0.0001
/// </summary>
public static class Task04
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 4: Ряд для (1 + 2x²)e^(x²) ===\n");
        
        const double a = 0.1, b = 1.0, h = 0.1;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 1.0; // первый член при i=0: -1·x⁰/(0)! не входит, начинаем с i=1
            double c = x * x; // для рекуррентного вычисления x^(2i)/(2i)!
            int i = 1;
            double term;
            
            do
            {
                term = (2 * i - 1) * c;
                s += term;
                c *= x * x / ((2 * i + 1) * (2 * i + 2));
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = (1 + 2 * x * x) * Math.Exp(x * x);
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
