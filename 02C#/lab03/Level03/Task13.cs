namespace Level3
{
    public static class Task13
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 13: Удалить повторяющиеся элементы");
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

            List<int> result = new List<int>();
            HashSet<int> seen = new HashSet<int>();

            for (int i = 0; i < arr.Length; i++)
            {
                if (!seen.Contains(arr[i]))
                {
                    result.Add(arr[i]);
                    seen.Add(arr[i]);
                }
            }

            Console.WriteLine();
            Console.WriteLine("Результат (без повторов):");
            foreach (int elem in result)
            {
                Console.Write($"{elem} ");
            }
            Console.WriteLine();
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
