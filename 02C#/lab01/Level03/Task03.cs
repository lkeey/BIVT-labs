namespace Level3;

/// <summary>
/// Задача 3: Вычислить сумму ряда s = Σ(cos(ix) / i!) для e^(cos x) · cos(sin x)
/// a = 0.1, b = 1, h = 0.1, eps = 0.0001
/// </summary>
public static class Task03
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 3: Ряд для e^(cos x) · cos(sin x) ===\n");
        
        const double a = 0.1, b = 1.0, h = 0.1;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 1.0; // первый член (i=0): cos(0)/0! = 1/1 = 1
            double term = 1.0;
            int factorial = 1;
            int i = 1;
            
            do
            {
                factorial *= i;
                term = Math.Cos(i * x) / factorial;
                s += term;
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = Math.Exp(Math.Cos(x)) * Math.Cos(Math.Sin(x));
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
