namespace Level2;

/// <summary>
/// Задача 10: Студенты без "2" и "3"
/// В группе n студентов. Каждый получил 4 оценки.
/// Подсчитать число студентов, не имеющих "2" и "3".
/// </summary>
public static class Task10
{
    public static void Execute()
    {
        Console.WriteLine("Задача 10: Студенты без '2' и '3'");
        Console.WriteLine();

        Console.Write("Введите количество студентов в группе: ");
        if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0)
        {
            Console.WriteLine("Ошибка: введите положительное целое число");
            return;
        }

        int studentsWithoutLowGrades = 0;
        int[] gradesDistribution = new int[6];

        Console.WriteLine();
        for (int i = 1; i <= n; i++)
        {
            Console.WriteLine($"Студент {i}:");
            Console.Write("  Введите 4 оценки через пробел: ");
            
            string? input = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("  Ошибка: некорректный ввод. Пропускаем студента.");
                continue;
            }

            string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length != 4)
            {
                Console.WriteLine($"  Ошибка: нужно ввести ровно 4 оценки. Пропускаем студента.");
                continue;
            }

            int[] grades = new int[4];
            bool validInput = true;
            
            for (int j = 0; j < 4; j++)
            {
                if (!int.TryParse(parts[j], out grades[j]) || grades[j] < 2 || grades[j] > 5)
                {
                    Console.WriteLine("  Ошибка: оценки должны быть в диапазоне 2-5");
                    validInput = false;
                    break;
                }
            }

            if (!validInput) continue;

            bool hasLowGrades = false;
            foreach (int grade in grades)
            {
                gradesDistribution[grade]++;
                if (grade == 2 || grade == 3)
                {
                    hasLowGrades = true;
                }
            }

            if (!hasLowGrades)
            {
                studentsWithoutLowGrades++;
                Console.WriteLine($"  Все оценки >= 4");
            }
            else
            {
                Console.WriteLine($"  Есть оценки '2' или '3'");
            }
        }

        Console.WriteLine();
        Console.WriteLine("РЕЗУЛЬТАТЫ:");
        Console.WriteLine($"Всего студентов: {n}");
        Console.WriteLine($"Студентов без '2' и '3': {studentsWithoutLowGrades}");
        Console.WriteLine($"Процент: {(double)studentsWithoutLowGrades / n * 100:F1}%");
    }
}
