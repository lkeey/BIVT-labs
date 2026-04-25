namespace Level3
{
    public static class Task11
    {
        public static void Execute()
        {
            Console.WriteLine("Задача 11: Экстремумы функции y = cos(x) + x*sin(x)");
            Console.WriteLine();

            Console.Write("Введите количество точек n: ");
            if (!int.TryParse(Console.ReadLine(), out int n) || n < 3)
            {
                Console.WriteLine("Ошибка: минимум 3 точки");
                return;
            }

            Console.Write("Введите начало отрезка a: ");
            if (!double.TryParse(Console.ReadLine(), out double a))
            {
                Console.WriteLine("Ошибка");
                return;
            }

            Console.Write("Введите конец отрезка b: ");
            if (!double.TryParse(Console.ReadLine(), out double b))
            {
                Console.WriteLine("Ошибка");
                return;
            }

            if (b <= a)
            {
                Console.WriteLine("Ошибка: b должно быть больше a");
                return;
            }

            double h = (b - a) / (n - 1);

            double[] X = new double[n];
            double[] Y = new double[n];

            Console.WriteLine();
            Console.WriteLine("Значения функции:");
            for (int i = 0; i < n; i++)
            {
                X[i] = a + i * h;
                Y[i] = Math.Cos(X[i]) + X[i] * Math.Sin(X[i]);
                Console.WriteLine($"x = {X[i]:F4}, y = {Y[i]:F4}");
            }

            double globalMax = Y[0], globalMin = Y[0];
            int globalMaxIndex = 0, globalMinIndex = 0;

            for (int i = 1; i < n; i++)
            {
                if (Y[i] > globalMax)
                {
                    globalMax = Y[i];
                    globalMaxIndex = i;
                }
                if (Y[i] < globalMin)
                {
                    globalMin = Y[i];
                    globalMinIndex = i;
                }
            }

            Console.WriteLine();
            Console.WriteLine("Локальные экстремумы:");

            for (int i = 1; i < n - 1; i++)
            {
                if (Y[i] > Y[i - 1] && Y[i] > Y[i + 1])
                {
                    Console.WriteLine($"Локальный максимум: x = {X[i]:F4}, y = {Y[i]:F4}");
                }
                else if (Y[i] < Y[i - 1] && Y[i] < Y[i + 1])
                {
                    Console.WriteLine($"Локальный минимум: x = {X[i]:F4}, y = {Y[i]:F4}");
                }
            }

            Console.WriteLine();
            Console.WriteLine("Глобальные экстремумы:");
            Console.WriteLine($"Глобальный максимум: x = {X[globalMaxIndex]:F4}, y = {globalMax:F4}");
            Console.WriteLine($"Глобальный минимум: x = {X[globalMinIndex]:F4}, y = {globalMin:F4}");
        }
    }
}
