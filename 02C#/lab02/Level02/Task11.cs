namespace Level2;

/// <summary>
/// Задача 11: Неуспевающие и средний балл
/// В группе n студентов. Каждый сдал 4 экзамена.
/// Подсчитать число неуспевающих студентов и средний балл группы.
/// </summary>
public static class Task11
{
    public static void Execute()
    {
        Console.WriteLine("Задача 11: Неуспевающие и средний балл");
        Console.WriteLine();

        Console.Write("Введите количество студентов в группе: ");
        if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0)
        {
            Console.WriteLine("Ошибка: введите положительное целое число");
            return;
        }

        int failingStudents = 0;
        int totalGradesSum = 0;
        int totalGradesCount = 0;
        List<(int studentId, double avgGrade, bool isFailing)> studentResults = new();

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

            studentResults.Add((i, studentAvg, isFailing));
        }

        double groupAverageGrade = totalGradesCount > 0 ? (double)totalGradesSum / totalGradesCount : 0;

        Console.WriteLine();
        Console.WriteLine("РЕЗУЛЬТАТЫ:");
        Console.WriteLine($"Всего студентов: {n}");
        Console.WriteLine($"Неуспевающих студентов: {failingStudents}");
        Console.WriteLine($"Успевающих студентов: {n - failingStudents}");
        Console.WriteLine($"Средний балл группы: {groupAverageGrade:F2}");
    }
}
