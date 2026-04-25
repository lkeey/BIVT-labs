namespace Level1
{
    public static class Task10
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 10: Подсчет элементов между P и Q");
            Console.WriteLine();

            int[] arr = { 3, 7, 1, 9, 4, 12, 2, 15, 6, 8 };
            int P = 3;
            int Q = 10;

            Console.WriteLine("Исходный массив:");
            PrintArray(arr);
            Console.WriteLine($"P = {P}, Q = {Q}");
            Console.WriteLine();

            int count = 0;
            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] > P && arr[i] < Q)
                {
                    count++;
                }
            }

            Console.WriteLine($"Количество элементов между P и Q: {count}");
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
