namespace Level3;

/// <summary>
/// Задача 12: Вычисление площадей (динамический ввод)
/// Количество значений заранее неизвестно.
/// Ввод прекращается, когда входной поток иссякнет.
/// </summary>
public static class Task12
{
    public static void Execute()
    {
        Console.WriteLine("Задача 12: Вычисление площадей (динамический ввод)");
        Console.WriteLine();

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
        Console.WriteLine("Для завершения ввода введите '-1' или отрицательное число");
        Console.WriteLine();

        int count = 0;
        double totalArea = 0;
        List<(double r, double area)> results = new();

        while (true)
        {
            Console.Write($"Введите значение r (или '-1' для завершения): ");
            string? input = Console.ReadLine();

            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("Ввод завершен.");
                break;
            }

            if (!double.TryParse(input, out double r))
            {
                Console.WriteLine("Ошибка: введите число");
                continue;
            }

            if (r < 0)
            {
                Console.WriteLine("Ввод завершен (получено отрицательное значение).");
                break;
            }

            if (r == 0)
            {
                Console.WriteLine("Предупреждение: r = 0, площадь будет равна 0");
            }

            double area = CalculateArea(figureType, r);
            count++;
            totalArea += area;
            results.Add((r, area));

            Console.WriteLine($"  r = {r:F4}, площадь = {area:F4}");
        }

        Console.WriteLine();

        if (count == 0)
        {
            Console.WriteLine("Данные не были введены.");
            return;
        }

        Console.WriteLine("РЕЗУЛЬТАТЫ:");
        Console.WriteLine($"Тип фигуры: {figureName}");
        Console.WriteLine($"Количество вычислений: {count}");
        Console.WriteLine($"Общая площадь: {totalArea:F4}");
        Console.WriteLine($"Средняя площадь: {totalArea / count:F4}");
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
