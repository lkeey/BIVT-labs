namespace Level3;

class Program
{
    static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        
        while (true)
        {
            Console.Clear();
            Console.WriteLine("╔════════════════════════════════════════════════════════════╗");
            Console.WriteLine("║   ЛАБОРАТОРНАЯ РАБОТА №1 - УРОВЕНЬ III                    ║");
            Console.WriteLine("║   Вложенные циклы, табулирование функций                  ║");
            Console.WriteLine("╚════════════════════════════════════════════════════════════╝");
            Console.WriteLine();
            Console.WriteLine("Выберите задачу (1-9) или 0 для выхода:");
            Console.WriteLine();
            Console.WriteLine(" 1. Ряд для cos(x)");
            Console.WriteLine(" 2. Ряд sin(4ix) / ((4i-1)(2-cos 4x))");
            Console.WriteLine(" 3. Ряд для e^(cos x) · cos(sin x)");
            Console.WriteLine(" 4. Ряд для (1 + 2x²)e^(x²)");
            Console.WriteLine(" 5. Ряд для cos²(x) / 3");
            Console.WriteLine(" 6. Ряд для (1 + x)arctg(x)");
            Console.WriteLine(" 7. Ряд для (e^x - e^(-x)) / 2 = sh(x)");
            Console.WriteLine(" 8. Ряд для e^x");
            Console.WriteLine(" 9. Ряд для arctg(x)");
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
