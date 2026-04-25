namespace Level3
{
    public static class Task10
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 10: Продублировать элементы");
            Console.WriteLine();

            Console.Write("Введите размер массива (удвоенный): ");
            if (!int.TryParse(Console.ReadLine(), out int n) || n <= 0 || n % 2 != 0)
            {
                Console.WriteLine("Ошибка: введите четное положительное число");
                return;
            }

            int halfSize = n / 2;
            int[] arr = new int[n];

            Console.WriteLine($"Введите {halfSize} элементов через пробел:");
            string? input = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("Ошибка");
                return;
            }

            string[] parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length != halfSize)
            {
                Console.WriteLine($"Ошибка: нужно {halfSize} элементов");
                return;
            }

            for (int i = 0; i < halfSize; i++)
            {
                if (!int.TryParse(parts[i], out arr[i]))
                {
                    Console.WriteLine("Ошибка");
                    return;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Исходный массив (заполнен наполовину):");
            for (int i = 0; i < halfSize; i++)
            {
                Console.Write($"{arr[i]} ");
            }
            Console.WriteLine();

            for (int i = halfSize - 1; i >= 0; i--)
            {
                arr[2 * i] = arr[i];
                arr[2 * i + 1] = arr[i];
            }

            Console.WriteLine();
            Console.WriteLine("Результат (продублированный):");
            for (int i = 0; i < n; i++)
            {
                Console.Write($"{arr[i]} ");
            }
            Console.WriteLine();
        }
    }
}
