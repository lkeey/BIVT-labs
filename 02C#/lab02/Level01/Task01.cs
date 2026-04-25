namespace Level1;

/// <summary>
/// Задача 1: Проверка принадлежности точки окружности
/// Определить, лежит ли заданная точка на окружности радиусом r = 2
/// Условие: |x² + y² - r²| ≤ 10⁻³
/// </summary>
public static class Task01
{
    public static void Execute()
    {
        Console.WriteLine("Задача 1: Точка на окружности");
        Console.WriteLine();

        const double r = 2.0;
        const double eps = 1e-3;

        var testPoints = new[]
        {
            (x: 0.0, y: 2.0),
            (x: 1.5, y: 0.7),
            (x: 1.0, y: 1.0),
            (x: 3.0, y: 0.0)
        };

        foreach (var (x, y) in testPoints)
        {
            double distanceSquared = x * x + y * y;
            double rSquared = r * r;
            double difference = Math.Abs(distanceSquared - rSquared);
            bool onCircle = difference <= eps;

            Console.WriteLine($"Точка ({x}, {y}): {(onCircle ? "на окружности" : "не на окружности")}");
        }
    }
}
