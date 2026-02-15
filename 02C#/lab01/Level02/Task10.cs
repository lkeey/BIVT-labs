namespace Level2;

/// <summary>
/// Задача 10: В последовательности 1/1, 2/1, 3/2, 5/3, 8/5, ...
/// вычислить член, который отличается от предыдущего не более чем на 0.001
/// </summary>
public static class Task10
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 10: Член последовательности с заданной точностью ===\n");
        
        const double epsilon = 0.001;
        
        int num1 = 1, den1 = 1;
        int num2 = 2, den2 = 1;
        
        double value1 = (double)num1 / den1;
        double value2 = (double)num2 / den2;
        double difference = Math.Abs(value2 - value1);
        
        int n = 2;
        
        Console.WriteLine($"Ищем член последовательности, который отличается");
        Console.WriteLine($"от предыдущего не более чем на {epsilon}\n");
        Console.WriteLine("№\tДробь\t\tЗначение\t\tРазность");
        Console.WriteLine("────────────────────────────────────────────────────");
        Console.WriteLine($"{1}\t{num1}/{den1}\t\t{value1:f6}\t\t-");
        Console.WriteLine($"{2}\t{num2}/{den2}\t\t{value2:f6}\t\t{difference:f6}");
        
        while (difference > epsilon)
        {
            n++;
            int numNext = num1 + num2;
            int denNext = den1 + den2;
            double valueNext = (double)numNext / denNext;
            
            difference = Math.Abs(valueNext - value2);
            
            Console.WriteLine($"{n}\t{numNext}/{denNext}\t\t{valueNext:f6}\t\t{difference:f6}");
            
            num1 = num2;
            den1 = den2;
            num2 = numNext;
            den2 = denNext;
            value2 = valueNext;
        }
        
        Console.WriteLine($"\nОтвет: {n}-й член последовательности {num2}/{den2} = {value2:f6}");
        Console.WriteLine($"Разность с предыдущим членом: {difference:f6}");
    }
}
