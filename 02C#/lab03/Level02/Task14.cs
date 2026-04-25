namespace Level2
{
    public static class Task14
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 14: Макс. в столбце → 0 или номер");
            Console.WriteLine();

            Console.Write("Введите количество строк (рекомендуется 7): ");
            if (!int.TryParse(Console.ReadLine(), out int rows) || rows <= 0)
            {
                Console.WriteLine("Ошибка");
                return;
            }

            Console.Write("Введите количество столбцов (рекомендуется 5): ");
            if (!int.TryParse(Console.ReadLine(), out int cols) || cols <= 0)
            {
                Console.WriteLine("Ошибка");
                return;
            }

            int[,] matrix = new int[rows, cols];

            Console.WriteLine("Введите элементы матрицы построчно (через пробел):");
            for (int i = 0; i < rows; i++)
            {
                Console.Write($"Строка {i + 1}: ");
                string? input = Console.ReadLine();
                if (string.IsNullOrWhiteSpace(input))
                {
                    Console.WriteLine("Ошибка");
                    return;
                }

                string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length != cols)
                {
                    Console.WriteLine($"Ошибка: нужно {cols} элементов");
                    return;
                }

                for (int j = 0; j < cols; j++)
                {
                    if (!int.TryParse(parts[j], out matrix[i, j]))
                    {
                        Console.WriteLine("Ошибка");
                        return;
                    }
                }
            }

            Console.WriteLine();
            Console.WriteLine("Исходная матрица:");
            PrintMatrix(matrix, rows, cols);

            for (int j = 0; j < cols; j++)
            {
                int positiveCount = 0;
                int negativeCount = 0;

                for (int i = 0; i < rows; i++)
                {
                    if (matrix[i, j] > 0)
                        positiveCount++;
                    else if (matrix[i, j] < 0)
                        negativeCount++;
                }

                int maxVal = matrix[0, j];
                int maxRow = 0;

                for (int i = 1; i < rows; i++)
                {
                    if (matrix[i, j] > maxVal)
                    {
                        maxVal = matrix[i, j];
                        maxRow = i;
                    }
                }

                if (positiveCount > negativeCount)
                {
                    matrix[maxRow, j] = 0;
                }
                else
                {
                    matrix[maxRow, j] = maxRow;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат:");
            PrintMatrix(matrix, rows, cols);
        }

        private static void PrintMatrix(int[,] matrix, int rows, int cols)
        {
            for (int i = 0; i < rows; i++)
            {
                for (int j = 0; j < cols; j++)
                {
                    Console.Write($"{matrix[i, j],4}");
                }
                Console.WriteLine();
            }
        }
    }
}
