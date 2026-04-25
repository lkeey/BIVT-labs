namespace Level3;

/// <summary>
/// Задача 10: Студенты без "2" и "3" (динамический ввод)
/// Количество студентов заранее неизвестно.
/// Ввод прекращается, когда входной поток иссякнет.
/// </summary>
public static class Task10
{
    public static void Execute()
    {
        Console.WriteLine("Задача 10: Студенты без '2' и '3' (динамический ввод)");
        Console.WriteLine();
        Console.WriteLine("Для завершения ввода введите '-1' вместо оценок");
        Console.WriteLine();

        int studentsWithoutLowGrades = 0;
        int totalStudents = 0;
        int[] gradesDistribution = new int[6];

        while (true)
        {
            Console.WriteLine($"Студент {totalStudents + 1}:");
            Console.Write("  Введите 4 оценки через пробел (или '-1' для завершения): ");
            
            string? input = Console.ReadLine();
            
            if (string.IsNullOrWhiteSpace(input) || input.Trim() == "-1")
            {
                Console.WriteLine("Ввод завершен.");
                break;
            }

            string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            
            if (parts.Length == 1 && parts[0] == "-1")
            {
                Console.WriteLine("Ввод завершен.");
                break;
            }

            if (parts.Length != 4)
            {
                Console.WriteLine($"  Ошибка: нужно ввести ровно 4 оценки. Попробуйте снова.");
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

            totalStudents++;

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

            Console.WriteLine();
        }

        if (totalStudents == 0)
        {
            Console.WriteLine("\nДанные не были введены.");
            return;
        }

        Console.WriteLine();
        Console.WriteLine("РЕЗУЛЬТАТЫ:");
        Console.WriteLine($"Всего студентов: {totalStudents}");
        Console.WriteLine($"Студентов без '2' и '3': {studentsWithoutLowGrades}");
        Console.WriteLine($"Процент: {(double)studentsWithoutLowGrades / totalStudents * 100:F1}%");
    }
}
