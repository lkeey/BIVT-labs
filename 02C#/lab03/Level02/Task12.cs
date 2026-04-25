namespace Level2
{
    public static class Task12
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 12: Первый отрицательный = сумме после максимального");
            Console.WriteLine();

            Console.Write("Введите размер массива: ");
            if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0)
            {
                Console.WriteLine("Ошибка: введите положительное число");
                return;
            }

            int[] arr = new int[n];
            Console.WriteLine("Введите элементы массива через пробел:");
            string? input = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("Ошибка ввода");
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
                    Console.WriteLine("Ошибка: некорректное число");
                    return;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int maxValue = arr[0];
            int maxIndex = 0;

            for (int i = 1; i < arr.Length; i++)
            {
                if (arr[i] > maxValue)
                {
                    maxValue = arr[i];
                    maxIndex = i;
                }
            }

            Console.WriteLine($"Максимальный: {maxValue} (индекс {maxIndex})");

            int sumAfterMax = 0;
            for (int i = maxIndex + 1; i < arr.Length; i++)
            {
                sumAfterMax += arr[i];
            }

            Console.WriteLine($"Сумма после максимального: {sumAfterMax}");

            int firstNegativeIndex = -1;
            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] < 0)
                {
                    firstNegativeIndex = i;
                    break;
                }
            }

            if (firstNegativeIndex != -1)
            {
                Console.WriteLine($"Первый отрицательный: {arr[firstNegativeIndex]} (индекс {firstNegativeIndex})");
                arr[firstNegativeIndex] = sumAfterMax;

                Console.WriteLine();
                Console.WriteLine("Результат:");
                PrintArray(arr);
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
