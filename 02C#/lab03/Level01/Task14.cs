namespace Level1
{
    public static class Task14
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 14: Сумма квадратов до первого отрицательного");
            Console.WriteLine();

            int[] arr = { 3, 5, 7, 2, -4, 8, 1, 9, 6, 4, 10 };

            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int sum = 0;
            int count = 0;

            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] < 0)
                {
                    Console.WriteLine($"Первый отрицательный элемент: {arr[i]} (индекс {i})");
                    break;
                }
                sum += arr[i] * arr[i];
                count++;
            }

            Console.WriteLine();
            Console.WriteLine($"Количество элементов до первого отрицательного: {count}");
            Console.WriteLine($"Сумма квадратов: {sum}");
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
