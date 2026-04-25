namespace Level1
{
    public static class Task19
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 19: Массив из количества отрицательных в столбцах");
            Console.WriteLine();

            int[,] matrix = {
                { 5, -2, 3 },
                { -8, 9, -10 },
                { 11, -12, 13 },
                { -14, 15, -16 }
            };

            Console.WriteLine("Исходная матрица:");
            PrintMatrix(matrix);

            int[] negativeCount = new int[3];

            for (int j = 0; j < 3; j++)
            {
                int count = 0;
                for (int i = 0; i < 4; i++)
                {
                    if (matrix[i, j] < 0)
                    {
                        count++;
                    }
                }
                negativeCount[j] = count;
            }

            Console.WriteLine();
            Console.WriteLine("Количество отрицательных элементов в каждом столбце:");
            for (int j = 0; j < 3; j++)
            {
                Console.WriteLine($"Столбец {j}: {negativeCount[j]}");
            }
        }

        private static void PrintMatrix(int[,] matrix)
        {
            for (int i = 0; i < 4; i++)
            {
                for (int j = 0; j < 3; j++)
                {
                    Console.Write($"{matrix[i, j],4}");
                }
                Console.WriteLine();
            }
        }
    }
}
