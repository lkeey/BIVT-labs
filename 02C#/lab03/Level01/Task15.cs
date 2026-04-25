namespace Level1
{
    public static class Task15
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 15: Поменять строку с макс. в 3-м столбце с 4-й строкой");
            Console.WriteLine();

            int[,] matrix = {
                { 1, 2, 5, 4, 3, 6, 7 },
                { 8, 9, 15, 11, 12, 13, 14 },
                { 15, 16, 3, 18, 19, 20, 21 },
                { 22, 23, 8, 25, 26, 27, 28 },
                { 29, 30, 12, 32, 33, 34, 35 }
            };

            Console.WriteLine("Исходная матрица:");
            PrintMatrix(matrix);

            int maxValue = matrix[0, 2];
            int maxRow = 0;

            for (int i = 1; i < 5; i++)
            {
                if (matrix[i, 2] > maxValue)
                {
                    maxValue = matrix[i, 2];
                    maxRow = i;
                }
            }

            Console.WriteLine($"Максимальный в 3-м столбце: {maxValue} (строка {maxRow})");

            for (int j = 0; j < 7; j++)
            {
                int temp = matrix[maxRow, j];
                matrix[maxRow, j] = matrix[3, j];
                matrix[3, j] = temp;
            }

            Console.WriteLine();
            Console.WriteLine("Результат:");
            PrintMatrix(matrix);
        }

        private static void PrintMatrix(int[,] matrix)
        {
            for (int i = 0; i < matrix.GetLength(0); i++)
            {
                for (int j = 0; j < matrix.GetLength(1); j++)
                {
                    Console.Write($"{matrix[i, j],4}");
                }
                Console.WriteLine();
            }
        }
    }
}
