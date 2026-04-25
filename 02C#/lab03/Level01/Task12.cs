namespace Level1
{
    public static class Task12
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 12: Последний отрицательный элемент");
            Console.WriteLine();

            int[] arr = { 5, -3, 8, -7, 12, -1, 4, 9 };

            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int lastNegativeIndex = -1;
            int lastNegativeValue = 0;

            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] < 0)
                {
                    lastNegativeIndex = i;
                    lastNegativeValue = arr[i];
                }
            }

            Console.WriteLine();
            if (lastNegativeIndex != -1)
            {
                Console.WriteLine($"Последний отрицательный элемент: {lastNegativeValue}");
                Console.WriteLine($"Номер (индекс): {lastNegativeIndex}");
            }
            else
            {
                Console.WriteLine("Отрицательных элементов нет");
            }
        }

        private static void PrintArray(int[] arr)
        {
            foreach (int elem in arr)
            {
                Console.Write($"{elem} ");
            }
            Console.WriteLine();
        }
    }
}
