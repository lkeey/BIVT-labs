namespace Level3
{
    public static class Task15
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 15: Заполнить периметр матрицы нулями");
            Console.WriteLine();

            Console.Write("Введите размер квадратной матрицы n: ");
            if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0)
            {
                Console.WriteLine("Ошибка");
                return;
            }

            int[,] matrix = new int[n, n];

            Console.WriteLine("Введите элементы матрицы построчно (через пробел):");
            for (int i = 0; i < n; i++)
            {
                Console.Write($"Строка {i + 1}: ");
                string? input = Console.ReadLine();
                if (string.IsNullOrWhiteSpace(input))
                {
                    Console.WriteLine("Ошибка");
                    return;
                }

                string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length != n)
                {
                    Console.WriteLine($"Ошибка: нужно {n} элементов");
                    return;
                }

                for (int j = 0; j < n; j++)
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
            PrintMatrix(matrix, n);

            for (int i = 0; i < n; i++)
            {
                if (i == 0 || i == n - 1)
                {
                    for (int j = 0; j < n; j++)
                    {
                        matrix[i, j] = 0;
                    }
                }
                else
                {
                    matrix[i, 0] = 0;
                    matrix[i, n - 1] = 0;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат (периметр заполнен нулями):");
            PrintMatrix(matrix, n);
        }

        private static void PrintMatrix(int[,] matrix, int n)
        {
            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j < n; j++)
                {
                    Console.Write($"{matrix[i, j],4}");
                }
                Console.WriteLine();
            }
        }
    }
}
