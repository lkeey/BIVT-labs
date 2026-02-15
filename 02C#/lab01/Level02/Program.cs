namespace Level2;

class Program
{
    static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        
        while (true)
        {
            Console.Clear();
            Console.WriteLine("╔════════════════════════════════════════════════════════════╗");
            Console.WriteLine("║   ЛАБОРАТОРНАЯ РАБОТА №1 - УРОВЕНЬ II                     ║");
            Console.WriteLine("║   Циклы по условию (while, do-while)                      ║");
            Console.WriteLine("╚════════════════════════════════════════════════════════════╝");
            Console.WriteLine();
            Console.WriteLine("Выберите задачу (1-10) или 0 для выхода:");
            Console.WriteLine();
            Console.WriteLine(" 1. Сумма ряда с условием точности ε = 0.0001");
            Console.WriteLine(" 2. Произведение 1·4·7·...·n с ограничением");
            Console.WriteLine(" 3. Количество членов арифметической прогрессии");
            Console.WriteLine(" 4. Геометрическая прогрессия 1 + x² + x⁴ + ...");
            Console.WriteLine(" 5. Деление через вычитание");
            Console.WriteLine(" 6. Размножение амеб до 10⁵ клеток");
            Console.WriteLine(" 7. Тренировки спортсмена (3 подзадачи)");
            Console.WriteLine(" 8. Вклад в банке под 8% до удвоения");
            Console.WriteLine(" 9. Разрезание нити до атомного размера");
            Console.WriteLine("10. Член последовательности с заданной точностью");
            Console.WriteLine();
            Console.Write("Ваш выбор: ");
            
            if (!int.TryParse(Console.ReadLine(), out int choice))
            {
                Console.WriteLine("Неверный ввод! Нажмите любую клавишу...");
                Console.ReadKey();
                continue;
            }
            
            if (choice == 0) break;
            
            Console.WriteLine();
            
            try
            {
                switch (choice)
                {
                    case 1: Task01.Execute(); break;
                    case 2: Task02.Execute(); break;
                    case 3: Task03.Execute(); break;
                    case 4: Task04.Execute(); break;
                    case 5: Task05.Execute(); break;
                    case 6: Task06.Execute(); break;
                    case 7: Task07.Execute(); break;
                    case 8: Task08.Execute(); break;
                    case 9: Task09.Execute(); break;
                    case 10: Task10.Execute(); break;
                    default:
                        Console.WriteLine("Задача с таким номером не найдена!");
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"\nОшибка: {ex.Message}");
            }
            
            Console.WriteLine("\n\nНажмите любую клавишу для продолжения...");
            Console.ReadKey();
        }
        
        Console.WriteLine("\nДо свидания!");
    }
}
