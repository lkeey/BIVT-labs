namespace Level1
{
    public static class Task17
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 17: Удалить строку и столбец максимального элемента");
            Console.WriteLine();

            int[,] matrix = {
                { 1, 2, 3, 4, 5, 6, 7 },
                { 8, 9, 10, 11, 12, 13, 14 },
                { 15, 16, 45, 18, 19, 20, 21 },
                { 22, 23, 24, 25, 26, 27, 28 },
                { 29, 30, 31, 32, 33, 34, 35 },
                { 36, 37, 38, 39, 40, 41, 42 }
            };

            Console.WriteLine("Исходная матрица:");
            PrintMatrix(matrix, 6, 7);

            int maxValue = matrix[0, 0];
            int maxRow = 0;
            int maxCol = 0;

            for (int i = 0; i < 6; i++)
            {
                for (int j = 0; j < 7; j++)
                {
                    if (matrix[i, j] > maxValue)
                    {
                        maxValue = matrix[i, j];
                        maxRow = i;
                        maxCol = j;
                    }
                }
            }

            Console.WriteLine($"Максимальный элемент: {maxValue} (строка {maxRow}, столбец {maxCol})");

            int[,] result = new int[5, 6];

            for (int i = 0, resRow = 0; i < 6; i++)
            {
                if (i != maxRow)
                {
                    for (int j = 0, resCol = 0; j < 7; j++)
                    {
                        if (j != maxCol)
                        {
                            result[resRow, resCol] = matrix[i, j];
                            resCol++;
                        }
                    }
                    resRow++;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат:");
            PrintMatrix(result, 5, 6);
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
