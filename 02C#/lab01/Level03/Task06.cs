namespace Level3;

/// <summary>
/// Задача 6: Вычислить сумму ряда s = Σ((-1)^i · x^(2i+1) / ((2i+1) · 4^(2i+1)))
/// для (1+x)arctg(x)
/// a = 0.1, b = 1, h = 0.1, eps = 0.0001
/// </summary>
public static class Task06
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 6: Ряд для (1 + x)arctg(x) ===\n");
        
        const double a = 0.1, b = 1.0, h = 0.1;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = x; // первый член при i=0: x/(1·4) · 4 = x
            double c = -x * x * x / 3.0; // для рекуррентных вычислений
            int i = 1;
            double term = c;
            
            do
            {
                double denominator = (2 * i + 1) * Math.Pow(4, 2 * i + 1);
                term = Math.Pow(-1, i) * Math.Pow(x, 2 * i + 1) / denominator;
                s += term;
                i++;
            }
            while (Math.Abs(term) >= eps);
            
            double y = (1 + x) * Math.Atan(x);
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {i,3}");
        }
    }
}
