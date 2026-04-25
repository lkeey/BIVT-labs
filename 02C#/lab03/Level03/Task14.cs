namespace Level3
{
    public static class Task14
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 14: Переставить строки по убыванию минимумов");
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

            int[] minValues = new int[rows];
            for (int i = 0; i < rows; i++)
            {
                int minVal = matrix[i, 0];
                for (int j = 1; j < cols; j++)
                {
                    if (matrix[i, j] < minVal)
                    {
                        minVal = matrix[i, j];
                    }
                }
                minValues[i] = minVal;
            }

            for (int i = 0; i < rows - 1; i++)
            {
                for (int k = 0; k < rows - i - 1; k++)
                {
                    if (minValues[k] < minValues[k + 1])
                    {
                        for (int j = 0; j < cols; j++)
                        {
                            int temp = matrix[k, j];
                            matrix[k, j] = matrix[k + 1, j];
                            matrix[k + 1, j] = temp;
                        }

                        int tempMin = minValues[k];
                        minValues[k] = minValues[k + 1];
                        minValues[k + 1] = tempMin;
                    }
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат (строки упорядочены по убыванию минимумов):");
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
