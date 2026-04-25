namespace Level3
{
    public static class Task16
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 16: Суммы диагоналей → вектор");
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

            int[] diagonalSums = new int[2 * n - 1];

            for (int k = -(n - 1); k <= (n - 1); k++)
            {
                int sum = 0;
                for (int i = 0; i < n; i++)
                {
                    int j = i - k;
                    if (j >= 0 && j < n)
                    {
                        sum += matrix[i, j];
                    }
                }
                diagonalSums[k + n - 1] = sum;
            }

            Console.WriteLine();
            Console.WriteLine("Суммы диагоналей (параллельных главной):");
            for (int i = 0; i < diagonalSums.Length; i++)
            {
                Console.Write($"{diagonalSums[i]} ");
            }
            Console.WriteLine();
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
