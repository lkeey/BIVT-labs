namespace Level1
{
    public static class Task16
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 16: Удалить строку с минимальным в 1-м столбце");
            Console.WriteLine();

            int[,] matrix = {
                { 5, 2, 3, 4, 5, 6, 7 },
                { 8, 9, 10, 11, 12, 13, 14 },
                { 2, 16, 17, 18, 19, 20, 21 },
                { 22, 23, 24, 25, 26, 27, 28 },
                { 29, 30, 31, 32, 33, 34, 35 }
            };

            Console.WriteLine("Исходная матрица:");
            PrintMatrix(matrix, 5, 7);

            int minValue = matrix[0, 0];
            int minRow = 0;

            for (int i = 1; i < 5; i++)
            {
                if (matrix[i, 0] < minValue)
                {
                    minValue = matrix[i, 0];
                    minRow = i;
                }
            }

            Console.WriteLine($"Минимальный в 1-м столбце: {minValue} (строка {minRow})");

            int[,] result = new int[4, 7];

            for (int i = 0, resRow = 0; i < 5; i++)
            {
                if (i != minRow)
                {
                    for (int j = 0; j < 7; j++)
                    {
                        result[resRow, j] = matrix[i, j];
                    }
                    resRow++;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат:");
            PrintMatrix(result, 4, 7);
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
