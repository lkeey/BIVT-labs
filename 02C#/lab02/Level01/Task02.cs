namespace Level1;

/// <summary>
/// Задача 2: Определить, лежит ли точка внутри или вне треугольника
/// Треугольник с вершинами в точках (-1, 0), (1, 0), (0, 1)
/// </summary>
public static class Task02
{
    public static void Execute()
    {
        Console.WriteLine("Задача 2: Точка внутри/вне треугольника");
        Console.WriteLine();

        var testPoints = new[]
        {
            (x: 0.0, y: 0.5, name: "Центр треугольника"),
            (x: -0.5, y: 0.3, name: "Внутри слева"),
            (x: 0.5, y: 0.3, name: "Внутри справа"),
            (x: 0.0, y: 0.0, name: "Вершина B (основание)"),
            (x: 0.0, y: 1.0, name: "Вершина C (вершина)"),
            (x: 1.5, y: 0.5, name: "Вне треугольника"),
            (x: 0.0, y: -0.5, name: "Ниже треугольника")
        };

        foreach (var (x, y, name) in testPoints)
        {
            bool inside = IsInsideTriangle(x, y);
            Console.WriteLine($"Точка ({x:F2}, {y:F2}) - {name}: {(inside ? "внутри" : "снаружи")}");
        }
    }

    private static bool IsInsideTriangle(double x, double y)
    {
        // Точка внутри треугольника, если выполняются все условия:
        // 1. y >= 0 (не ниже основания)
        // 2. y <= 1 + x (для x < 0, левая сторона)
        // 3. y <= 1 - x (для x >= 0, правая сторона)
        
        if (y < 0) return false;  // Ниже основания
        
        if (x < 0)
        {
            return y <= 1 + x;  // Левая граница
        }
        else
        {
            return y <= 1 - x;  // Правая граница
        }
    }
}
