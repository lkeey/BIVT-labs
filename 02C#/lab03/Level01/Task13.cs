namespace Level1
{
    public static class Task13
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 13: Разделить массив на четные и нечетные индексы");
            Console.WriteLine();

            int[] arr = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int[] evenIndexArray = new int[5];
            int[] oddIndexArray = new int[5];

            for (int i = 0; i < 5; i++)
            {
                evenIndexArray[i] = arr[i * 2];
                oddIndexArray[i] = arr[i * 2 + 1];
            }

            Console.WriteLine();
            Console.WriteLine("Массив с четными индексами (0, 2, 4, 6, 8):");
            PrintArray(evenIndexArray);

            Console.WriteLine();
            Console.WriteLine("Массив с нечетными индексами (1, 3, 5, 7, 9):");
            PrintArray(oddIndexArray);
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
