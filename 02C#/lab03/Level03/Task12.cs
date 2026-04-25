namespace Level3
{
    public static class Task12
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 12: Удалить все отрицательные элементы");
            Console.WriteLine();

            int[] arr = new int[12];

            Console.WriteLine("Введите 12 элементов через пробел:");
            string? input = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("Ошибка");
                return;
            }

            string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length != 12)
            {
                Console.WriteLine("Ошибка: нужно 12 элементов");
                return;
            }

            for (int i = 0; i < 12; i++)
            {
                if (!int.TryParse(parts[i], out arr[i]))
                {
                    Console.WriteLine("Ошибка");
                    return;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int positiveCount = 0;
            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] >= 0)
                {
                    positiveCount++;
                }
            }

            int[] result = new int[positiveCount];
            int index = 0;

            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] >= 0)
                {
                    result[index] = arr[i];
                    index++;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат (без отрицательных):");
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
