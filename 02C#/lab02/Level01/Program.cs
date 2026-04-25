namespace Level1;

/// <summary>
/// Лабораторная работа №2. Уровень I: Базовые разветвления
/// Выполнил: Кирюшин Алексей, БИВТ-25-1
/// </summary>
class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("===========================================");
        Console.WriteLine("Лабораторная работа №2. Уровень I");
        Console.WriteLine("Организация разветвлений");
        Console.WriteLine("Выполнил: Кирюшин Алексей, БИВТ-25-1");
        Console.WriteLine("===========================================");
        Console.WriteLine();

        while (true)
        {
            Console.WriteLine("\n=== МЕНЮ ===");
            Console.WriteLine("1. Задача 1: Точка на окружности");
            Console.WriteLine("2. Задача 2: Точка в треугольнике");
            Console.WriteLine("3. Задача 3: Условный max/min");
            Console.WriteLine("4. Задача 4: Вложенные операции max/min");
            Console.WriteLine("5. Задача 10: Кусочная функция");
            Console.WriteLine("0. Выход");
            Console.Write("\nВыберите задачу: ");

            string? input = Console.ReadLine();
            if (!int.TryParse(input, out int choice))
            {
                Console.WriteLine("Ошибка: введите число от 0 до 5");
                continue;
            }

            Console.WriteLine();

            switch (choice)
            {
                case 1:
                    Task01.Execute();
                    break;
                case 2:
                    Task02.Execute();
                    break;
                case 3:
                    Task03.Execute();
                    break;
                case 4:
                    Task04.Execute();
                    break;
                case 5:
                    Task10.Execute();
                    break;
                case 0:
                    Console.WriteLine("Завершение программы...");
                    return;
                default:
                    Console.WriteLine("Ошибка: выберите число от 0 до 5");
                    break;
            }

            Console.WriteLine("\nНажмите любую клавишу для продолжения...");
            Console.ReadKey();
            Console.Clear();
        }
    }
}
