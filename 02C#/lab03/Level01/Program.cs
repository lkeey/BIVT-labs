namespace Level1
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("===========================================");
            Console.WriteLine("Лабораторная работа №3. Уровень I");
            Console.WriteLine("Массивы и матрицы");
            Console.WriteLine("Выполнил: Кирюшин Алексей, БИВТ-25-1");
            Console.WriteLine("===========================================");
            Console.WriteLine();

            while (true)
            {
                Console.WriteLine("=== МЕНЮ ===");
                Console.WriteLine("Одномерные массивы:");
                Console.WriteLine("1. Задача 10: Подсчет элементов между P и Q");
                Console.WriteLine("2. Задача 11: Сформировать массив из положительных");
                Console.WriteLine("3. Задача 12: Последний отрицательный элемент");
                Console.WriteLine("4. Задача 13: Разделить на четные/нечетные индексы");
                Console.WriteLine("5. Задача 14: Сумма квадратов до первого отрицательного");
                Console.WriteLine();
                Console.WriteLine("Матрицы:");
                Console.WriteLine("6. Задача 15: Поменять строку с макс. в 3-м столбце с 4-й строкой");
                Console.WriteLine("7. Задача 16: Удалить строку с мин. в 1-м столбце");
                Console.WriteLine("8. Задача 17: Удалить строку и столбец макс. элемента");
                Console.WriteLine("9. Задача 18: Поменять 4-й столбец со столбцом макс. на диагонали");
                Console.WriteLine("10. Задача 19: Массив из кол-ва отрицательных в столбцах");
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
                    case "8":
                        Task17.Execute();
                        break;
                    case "9":
                        Task18.Execute();
                        break;
                    case "10":
                        Task19.Execute();
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
