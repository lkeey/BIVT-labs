namespace Level1;

/// <summary>
/// Задача 10: Кусочная функция
/// Вычислить y при заданном x:
///   y = 1,  если x ≤ -1
///   y = -x, если -1 < x ≤ 1
///   y = -1, если x > 1
/// </summary>
public static class Task10
{
    public static void Execute()
    {
        Console.WriteLine("Задача 10: Кусочная функция");
        Console.WriteLine();

        double[] testValues = { -3.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0 };

        foreach (double x in testValues)
        {
            double y = CalculatePiecewiseFunction(x);
            Console.WriteLine($"x = {x,6:F2} => y = {y,6:F2}");
        }
    }

    private static double CalculatePiecewiseFunction(double x)
    {
        if (x <= -1)
            return 1;
        else if (x <= 1)
            return -x;
        else
            return -1;
    }
}
