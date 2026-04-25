namespace Level2;

/// <summary>
/// Задача 12: Вычисление площадей с множественным выбором
/// Ввести n значений r, вычислить по выбору площадь квадрата,
/// круга или равностороннего треугольника
/// </summary>
public static class Task12
{
    public static void Execute()
    {
        Console.WriteLine("Задача 12: Вычисление площадей");
        Console.WriteLine();

        Console.Write("Введите количество значений для вычисления: ");
        if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0)
        {
            Console.WriteLine("Ошибка: введите положительное целое число");
            return;
        }

        Console.Write("Выберите тип фигуры (1-квадрат, 2-круг, 3-треугольник): ");
        if (!int.TryParse(Console.ReadLine(), out int figureType) || figureType < 1 || figureType > 3)
        {
            Console.WriteLine("Ошибка: выберите 1, 2 или 3");
            return;
        }

        string figureName = figureType switch
        {
            1 => "Квадрат",
            2 => "Круг",
            3 => "Равносторонний треугольник",
            _ => ""
        };

        Console.WriteLine();
        Console.WriteLine($"Вычисление площади: {figureName}");
        Console.WriteLine();

        for (int i = 1; i <= n; i++)
        {
            Console.Write($"Введите значение r ({i}/{n}): ");
            if (!double.TryParse(Console.ReadLine(), out double r) || r <= 0)
            {
                Console.WriteLine("Ошибка: введите положительное число");
                i--;
                continue;
            }

            double area = CalculateArea(figureType, r);
            Console.WriteLine($"  r = {r:F4}, площадь = {area:F4}");
        }
    }
    private static double CalculateArea(int figureType, double r)
    {
        switch (figureType)
        {
            case 1:
                // Площадь квадрата: S = r²
                return r * r;
            
            case 2:
                // Площадь круга: S = πr²
                return Math.PI * r * r;
            
            case 3:
                // Площадь равностороннего треугольника: S = (r²√3)/4
                return (r * r * Math.Sqrt(3)) / 4;
            
            default:
                throw new ArgumentException("Неверный тип фигуры");
        }
    }
}
