namespace Level1;

/// <summary>
/// Задача 4: Вложенные операции max/min
/// Для заданных a, b, c вычислить z = max(min(a, b), c)
/// </summary>
public static class Task04
{
    public static void Execute()
    {
        Console.WriteLine("Задача 4: Вложенные операции max/min");
        Console.WriteLine();

        var testCases = new[]
        {
            (a: 5.0, b: 3.0, c: 4.0),
            (a: 10.0, b: 8.0, c: 12.0),
            (a: 2.0, b: 7.0, c: 1.0),
            (a: -5.0, b: -3.0, c: -4.0),
            (a: 0.0, b: 5.0, c: 2.5),
            (a: 15.0, b: 10.0, c: 8.0)
        };

        foreach (var (a, b, c) in testCases)
        {
            double minAB = Math.Min(a, b);
            double z = Math.Max(minAB, c);

            Console.WriteLine($"a = {a,6:F2}, b = {b,6:F2}, c = {c,6:F2} => z = {z:F2}");
        }
    }
}
