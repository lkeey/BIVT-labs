namespace Level2
{
    public static class Task13
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 13: Макс. с четным индексом → его индекс");
            Console.WriteLine();

            Console.Write("Введите размер массива: ");
            if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0)
            {
                Console.WriteLine("Ошибка");
                return;
            }

            int[] arr = new int[n];
            Console.WriteLine("Введите элементы массива через пробел:");
            string? input = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("Ошибка");
                return;
            }

            string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length != n)
            {
                Console.WriteLine($"Ошибка: нужно {n} элементов");
                return;
            }

            for (int i = 0; i < n; i++)
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

            int maxValue = int.MinValue;
            int maxIndex = -1;
            bool hasEvenIndex = false;

            for (int i = 0; i < arr.Length; i += 2)
            {
                hasEvenIndex = true;
                if (arr[i] > maxValue)
                {
                    maxValue = arr[i];
                    maxIndex = i;
                }
            }

            if (hasEvenIndex && maxIndex != -1)
            {
                Console.WriteLine($"Максимальный с четным индексом: {maxValue} (индекс {maxIndex})");
                arr[maxIndex] = maxIndex;

                Console.WriteLine();
                Console.WriteLine("Результат:");
                PrintArray(arr);
            }
            else
            {
                Console.WriteLine("Нет элементов с четными индексами");
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
