namespace Level1
{
    public static class Task11
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 11: Сформировать массив из положительных элементов");
            Console.WriteLine();

            int[] arr = { 5, -3, 8, 2, -7, 12, 4, -1, 9, -6 };

            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int positiveCount = 0;
            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] > 0)
                {
                    positiveCount++;
                }
            }

            int[] result = new int[positiveCount];
            int index = 0;

            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] > 0)
                {
                    result[index] = arr[i];
                    index++;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Массив положительных элементов:");
            PrintArray(result);
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
