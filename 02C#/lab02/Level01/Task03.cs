namespace Level1;

/// <summary>
/// Задача 3: Условный max/min
/// Для заданных a и b получить c = max(a, b), если a ≥ 0
/// или c = min(a, b), если a < 0
/// </summary>
public static class Task03
{
    public static void Execute()
    {
        Console.WriteLine("Задача 3: Условный max/min");
        Console.WriteLine();

        var testCases = new[]
        {
            (a: 5.0, b: 3.0),
            (a: -5.0, b: 3.0),
            (a: 5.0, b: 10.0),
            (a: -5.0, b: -10.0),
            (a: 0.0, b: -3.0),
            (a: -2.5, b: -1.5)
        };

        foreach (var (a, b) in testCases)
        {
            double c;
            string operation;

            if (a >= 0)
            {
                c = Math.Max(a, b);
                operation = "max(a, b)";
            }
            else
            {
                c = Math.Min(a, b);
                operation = "min(a, b)";
            }

            Console.WriteLine($"a = {a,6:F2}, b = {b,6:F2} => c = {c,6:F2} ({operation})");
        }
    }
}
