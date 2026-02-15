namespace Level3;

/// <summary>
/// Задача 5: Вычислить сумму ряда s = 1 + Σ(cos(ix) / 4^i) для cos²(x)/3
/// a = π/5, b = π, h = π/25, eps = 0.0001
/// </summary>
public static class Task05
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 5: Ряд для cos²(x) / 3 ===\n");
        
        double a = Math.PI / 5;
        double b = Math.PI;
        double h = Math.PI / 25;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [π/5, π], шаг: π/25, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 1.0;
            double term;
            int i = 1;
            double power4 = 4.0;
            
            do
            {
                term = Math.Cos(i * x) / power4;
                s += term;
                i++;
                power4 *= 4;
            }
            while (Math.Abs(term) >= eps);
            
            double cosX = Math.Cos(x);
            double y = cosX * cosX / 3.0;
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f4} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
