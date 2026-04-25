namespace Level2
{
    public static class Task11
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 11: Вставить элемент P после последнего положительного");
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

            Console.Write("Введите элемент P для вставки: ");
            if (!int.TryParse(Console.ReadLine(), out int P))
            {
                Console.WriteLine("Ошибка ввода");
                return;
            }

            Console.WriteLine();
            Console.WriteLine("Исходный массив:");
            PrintArray(arr);

            int lastPositiveIndex = -1;

            for (int i = 0; i < arr.Length; i++)
            {
                if (arr[i] > 0)
                {
                    lastPositiveIndex = i;
                }
            }

            if (lastPositiveIndex != -1)
            {
                Console.WriteLine($"Последний положительный: {arr[lastPositiveIndex]} (индекс {lastPositiveIndex})");

                int[] result = new int[arr.Length + 1];
                
                for (int i = 0; i <= lastPositiveIndex; i++)
                {
                    result[i] = arr[i];
                }
                
                result[lastPositiveIndex + 1] = P;
                
                for (int i = lastPositiveIndex + 1; i < arr.Length; i++)
                {
                    result[i + 1] = arr[i];
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
