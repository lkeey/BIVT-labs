namespace Level1;

/// <summary>
/// Задача 12: Вычислить при заданном x сумму s = 1 + 1/x + 1/x² + ... + 1/x¹⁰
/// </summary>
public static class Task12
{
    public static void Execute()
    {
        
        Console.Write("Введите значение x: ");
        double x = double.Parse(Console.ReadLine() ?? "2.0");
        
        double sum = 0;
        double xPower = 1;
        
        for (int i = 0; i <= 10; i++)
        {
            double term = 1.0 / xPower;
            sum += term;
            xPower *= x;
        }
        
        Console.WriteLine($"\nПри x = {x:f2}, сумма s = {sum:f6}");
    }
}
