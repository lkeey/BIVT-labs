namespace Level3;

/// <summary>
/// Задача 11: Неуспевающие и средний балл (динамический ввод)
/// Количество студентов заранее неизвестно.
/// Ввод прекращается, когда входной поток иссякнет.
/// </summary>
public static class Task11
{
    public static void Execute()
    {
        Console.WriteLine("Задача 11: Неуспевающие и средний балл (динамический ввод)");
        Console.WriteLine();
        Console.WriteLine("Для завершения ввода введите '-1' вместо оценок");
        Console.WriteLine();

        int failingStudents = 0;
        int totalStudents = 0;
        int totalGradesSum = 0;
        int totalGradesCount = 0;
        List<(int studentId, double avgGrade, bool isFailing)> studentResults = new();

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

            bool isFailing = false;
            int studentSum = 0;
            
            foreach (int grade in grades)
            {
                studentSum += grade;
                if (grade == 2)
                {
                    isFailing = true;
                }
            }

            double studentAvg = studentSum / 4.0;
            totalGradesSum += studentSum;
            totalGradesCount += 4;

            if (isFailing)
            {
                failingStudents++;
                Console.WriteLine($"  Неуспевающий (средний балл: {studentAvg:F2})");
            }
            else
            {
                Console.WriteLine($"  Успевающий (средний балл: {studentAvg:F2})");
            }

            studentResults.Add((totalStudents, studentAvg, isFailing));
            Console.WriteLine();
        }

        if (totalStudents == 0)
        {
            Console.WriteLine("\nДанные не были введены.");
            return;
        }

        double groupAverageGrade = totalGradesCount > 0 ? (double)totalGradesSum / totalGradesCount : 0;

        Console.WriteLine();
        Console.WriteLine("РЕЗУЛЬТАТЫ:");
        Console.WriteLine($"Всего студентов: {totalStudents}");
        Console.WriteLine($"Неуспевающих студентов: {failingStudents}");
        Console.WriteLine($"Успевающих студентов: {totalStudents - failingStudents}");
        Console.WriteLine($"Средний балл группы: {groupAverageGrade:F2}");
    }
}
