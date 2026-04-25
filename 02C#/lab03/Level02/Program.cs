namespace Level2
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("===========================================");
            Console.WriteLine("Лабораторная работа №3. Уровень II");
            Console.WriteLine("Массивы и матрицы (с вводом данных)");
            Console.WriteLine("Выполнил: Кирюшин Алексей, БИВТ-25-1");
            Console.WriteLine("===========================================");
            Console.WriteLine();

            while (true)
            {
                Console.WriteLine("=== МЕНЮ ===");
                Console.WriteLine("Одномерные массивы:");
                Console.WriteLine("1. Задача 10: Удалить минимальный положительный");
                Console.WriteLine("2. Задача 11: Вставить P после последнего положительного");
                Console.WriteLine("3. Задача 12: Первый отрицательный = сумме после макс.");
                Console.WriteLine("4. Задача 13: Макс. с четным индексом → его индекс");
                Console.WriteLine();
                Console.WriteLine("Матрицы:");
                Console.WriteLine("5. Задача 14: Макс. в столбце → 0 или номер");
                Console.WriteLine("6. Задача 15: 1-й элемент столбца = сумме после макс.");
                Console.WriteLine("7. Задача 16: Сравнить соседей макс., меньшего увеличить");
                Console.WriteLine("0. Выход");
                Console.WriteLine();

                Console.Write("Выберите задачу: ");
                string? choice = Console.ReadLine();

                Console.WriteLine();

                switch (choice)
                {
                    case "1":
                        Task10.Execute();
                        break;
                    case "2":
                        Task11.Execute();
                        break;
                    case "3":
                        Task12.Execute();
                        break;
                    case "4":
                        Task13.Execute();
                        break;
                    case "5":
                        Task14.Execute();
                        break;
                    case "6":
                        Task15.Execute();
                        break;
                    case "7":
                        Task16.Execute();
                        break;
                    case "0":
                        return;
                    default:
                        Console.WriteLine("Неверный выбор. Попробуйте снова.");
                        break;
                }

                Console.WriteLine();
                Console.WriteLine("Нажмите любую клавишу для продолжения...");
                Console.ReadKey();
                Console.Clear();
            }
        }
    }
}
