namespace Level3;

/// <summary>
/// Лабораторная работа №2. Уровень III: Динамический ввод
/// Выполнил: Кирюшин Алексей, БИВТ-25-1
/// </summary>
class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("===========================================");
        Console.WriteLine("Лабораторная работа №2. Уровень III");
        Console.WriteLine("Динамический ввод (количество данных неизвестно)");
        Console.WriteLine("Выполнил: Кирюшин Алексей, БИВТ-25-1");
        Console.WriteLine("===========================================");
        Console.WriteLine();

        while (true)
        {
            Console.WriteLine("\n=== МЕНЮ ===");
            Console.WriteLine("1. Задача 10: Студенты без '2' и '3' (динамический ввод)");
            Console.WriteLine("2. Задача 11: Неуспевающие и средний балл (динамический ввод)");
            Console.WriteLine("3. Задача 12: Вычисление площадей (динамический ввод)");
            Console.WriteLine("0. Выход");
            Console.Write("\nВыберите задачу: ");

            string? input = Console.ReadLine();
            if (!int.TryParse(input, out int choice))
            {
                Console.WriteLine("Ошибка: введите число от 0 до 3");
                continue;
            }

            Console.WriteLine();

            switch (choice)
            {
                case 1:
                    Task10.Execute();
                    break;
                case 2:
                    Task11.Execute();
                    break;
                case 3:
                    Task12.Execute();
                    break;
                case 0:
                    Console.WriteLine("Завершение программы...");
                    return;
                default:
                    Console.WriteLine("Ошибка: выберите число от 0 до 3");
                    break;
            }

            Console.WriteLine("\nНажмите любую клавишу для продолжения...");
            Console.ReadKey();
            Console.Clear();
        }
    }
}
