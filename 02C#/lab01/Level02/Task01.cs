namespace Level2;

/// <summary>
/// Задача 1: Вычислить сумму s = cos x + (cos 2x)/2² + ... + (cos nx)/n² + ...
/// Суммирование прекратить, когда очередной член по модулю меньше ε = 0.0001
/// </summary>
public static class Task01
{
    public static void Execute()
    {        
        Console.Write("Введите значение x: ");
        double x = double.Parse(Console.ReadLine() ?? "1.0");
        
        const double eps = 0.0001;
        double sum = 0;
        int n = 1;
        double term;
        
        do
        {
            term = Math.Cos(n * x) / (n * n);
            sum += term;
            n++;
        }
        while (Math.Abs(term) >= eps);
        
        Console.WriteLine($"\nКоличество членов ряда: {n - 1}");
        Console.WriteLine($"Итоговая сумма s = {sum:f6}");
    }
}
