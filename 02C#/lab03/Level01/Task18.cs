namespace Level1
{
    public static class Task18
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 18: Поменять 4-й столбец со столбцом макс. на диагонали");
            Console.WriteLine();

            int[,] matrix = {
                { 3, 2, 5, 4, 8 },
                { 6, 12, 8, 9, 10 },
                { 11, 12, 7, 14, 15 },
                { 16, 17, 18, 19, 20 },
                { 21, 22, 23, 24, 25 }
            };

            Console.WriteLine("Исходная матрица:");
            PrintMatrix(matrix);

            int maxValue = matrix[0, 0];
            int maxIndex = 0;

            for (int i = 1; i < 5; i++)
            {
                if (matrix[i, i] > maxValue)
                {
                    maxValue = matrix[i, i];
                    maxIndex = i;
                }
            }

            Console.WriteLine($"Максимальный на диагонали: {maxValue} (позиция [{maxIndex},{maxIndex}])");

            for (int i = 0; i < 5; i++)
            {
                int temp = matrix[i, 3];
                matrix[i, 3] = matrix[i, maxIndex];
                matrix[i, maxIndex] = temp;
            }

            Console.WriteLine();
            Console.WriteLine("Результат:");
            PrintMatrix(matrix);
        }

        private static void PrintMatrix(int[,] matrix)
        {
            for (int i = 0; i < 5; i++)
            {
                for (int j = 0; j < 5; j++)
                {
                    Console.Write($"{matrix[i, j],4}");
                }
                Console.WriteLine();
            }
        }
    }
}
