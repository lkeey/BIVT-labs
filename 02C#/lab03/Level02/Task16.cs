namespace Level2
{
    public static class Task16
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 16: Сравнить соседей макс., меньшего увеличить вдвое");
            Console.WriteLine();

            Console.Write("Введите количество строк (рекомендуется 5): ");
            if (!int.TryParse(Console.ReadLine(), out int rows) || rows <= 0)
            {
                Console.WriteLine("Ошибка");
                return;
            }

            Console.Write("Введите количество столбцов (рекомендуется 7): ");
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

            for (int i = 0; i < rows; i++)
            {
                int maxVal = matrix[i, 0];
                int maxCol = 0;

                for (int j = 1; j < cols; j++)
                {
                    if (matrix[i, j] > maxVal)
                    {
                        maxVal = matrix[i, j];
                        maxCol = j;
                    }
                }

                if (maxCol > 0 && maxCol < cols - 1)
                {
                    int before = matrix[i, maxCol - 1];
                    int after = matrix[i, maxCol + 1];

                    if (before < after)
                    {
                        matrix[i, maxCol - 1] *= 2;
                    }
                    else
                    {
                        matrix[i, maxCol + 1] *= 2;
                    }
                }
                else if (maxCol == 0 && cols > 1)
                {
                    matrix[i, 1] *= 2;
                }
                else if (maxCol == cols - 1 && cols > 1)
                {
                    matrix[i, cols - 2] *= 2;
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
