namespace Level3;

/// <summary>
/// Задача 2: Вычислить сумму ряда s = Σ(sin(4ix) / ((4i-1)(2-cos(4x))))
/// a = 0.1, b = 0.8, h = 0.1, eps = 0.0001
/// Сравнить с y = sin(4x) / (4(1-2cos(4x)))
/// </summary>
public static class Task02
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 2: Ряд sin(4ix) / ((4i-1)(2-cos(4x))) ===\n");
        
        const double a = 0.1, b = 0.8, h = 0.1;
        const double eps = 0.0001;
        
        Console.WriteLine($"Диапазон: [{a}, {b}], шаг: {h}, точность: {eps}\n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        Console.WriteLine("   x     │    s (ряд)   │      y       │  |s - y|  │  n");
        Console.WriteLine("───────────────────────────────────────────────────────────");
        
        for (double x = a; x <= b + 0.0001; x += h)
        {
            double s = 0;
            double term;
            int i = 1;
            int count = 0;
            
            // Согласно указанию из PDF: сравниваем только xi, так как второй множитель может быть 0
            do
            {
                double sinValue = Math.Sin(4 * i * x);
                double denominator = (4 * i - 1) * (2 - Math.Cos(4 * x));
                
                term = sinValue / denominator;
                
                // Проверяем условие только для sinValue
                if (Math.Abs(sinValue) >= eps)
                {
                    s += term;
                }
                
                i++;
                count++;
            }
            while (Math.Abs(Math.Sin(4 * i * x)) >= eps && count < 1000);
            
            double y = Math.Sin(4 * x) / (4 * (1 - 2 * Math.Cos(4 * x)));
            double error = Math.Abs(s - y);
            
            Console.WriteLine($"{x,7:f2} │ {s,12:f8} │ {y,12:f8} │ {error,9:e2} │ {count,3}");
        }
    }
}
