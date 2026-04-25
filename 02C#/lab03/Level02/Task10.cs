namespace Level2
{
    public static class Task10
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 10: Удалить минимальный положительный элемент");
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

            int minPositive = int.MaxValue;
            int minIndex = -1;

            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] > 0 && arr[i] < minPositive)
                {
                    minPositive = arr[i];
                    minIndex = i;
                }
            }

            if (minIndex != -1)
            {
                Console.WriteLine($"Минимальный положительный: {minPositive} (индекс {minIndex})");

                int[] result = new int[arr.Length - 1];
                for (int i = 0, j = 0; i < arr.Length; i++)
                {
                    if (i != minIndex)
                    {
                        result[j] = arr[i];
                        j++;
                    }
                }

                Console.WriteLine();
                Console.WriteLine("Результат:");
                PrintArray(result);
            }
            else
            {
                Console.WriteLine("Положительных элементов нет");
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
