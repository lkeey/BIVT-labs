namespace Level2;

/// <summary>
/// Задача 4: Вычислить s = 1 + x² + x⁴ + ... + x^(2n) (|x| < 1)
/// Вычисления прекратить, когда очередной член суммы меньше ε = 0.0001
/// </summary>
public static class Task04
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 4: Геометрическая прогрессия с условием точности ===\n");
        
        Console.Write("Введите значение x (|x| < 1): ");
        double x = double.Parse(Console.ReadLine() ?? "0.5");
        
        if (Math.Abs(x) >= 1)
        {
            Console.WriteLine("Ошибка: |x| должно быть меньше 1!");
            return;
        }
        
        const double eps = 0.0001;
        double sum = 0;
        double term = 1; // x^0 = 1
        int n = 0;
        
        do
        {
            sum += term;
            Console.WriteLine($"n={n}: x^{2*n} = {term,10:f6}, сумма = {sum:f6}");
            term *= x * x; // переход к следующему члену x^(2(n+1))
            n++;
        }
        while (term >= eps);
        
        Console.WriteLine($"\nКоличество членов ряда: {n}");
        Console.WriteLine($"Итоговая сумма s = {sum:f6}");
        
        // Для проверки: сумма геометрической прогрессии = 1/(1-x²)
        double exactSum = 1.0 / (1.0 - x * x);
        Console.WriteLine($"Точное значение (формула): {exactSum:f6}");
        Console.WriteLine($"Погрешность: {Math.Abs(sum - exactSum):f6}");
    }
}
