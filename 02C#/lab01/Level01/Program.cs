namespace Level1;

class Program
{
    static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        
        while (true)
        {
            Console.Clear();
            Console.WriteLine("╔════════════════════════════════════════════════════════════╗");
            Console.WriteLine("║   ЛАБОРАТОРНАЯ РАБОТА №1 - УРОВЕНЬ I                       ║");
            Console.WriteLine("║   Разработка программ циклической структуры                ║");
            Console.WriteLine("╚════════════════════════════════════════════════════════════╝");
            Console.WriteLine();
            Console.WriteLine("Выберите задачу (1-18) или 0 для выхода:");
            Console.WriteLine();
            Console.WriteLine(" 1. Сумма арифметической прогрессии 2+5+8+...+35");
            Console.WriteLine(" 2. Гармонический ряд 1+1/2+1/3+...+1/10");
            Console.WriteLine(" 3. Сумма 2/3+4/5+6/7+...+112/113");
            Console.WriteLine(" 4. Сумма cos x+(cos 2x)/x+...+(cos 9x)/x⁸");
            Console.WriteLine(" 5. Сумма квадратов арифметической прогрессии");
            Console.WriteLine(" 6. Табулирование функции y=0.5x²-7x");
            Console.WriteLine(" 7. Факториал 6!");
            Console.WriteLine(" 8. Сумма факториалов 1!+2!+...+6!");
            Console.WriteLine(" 9. Знакопеременный ряд с факториалами");
            Console.WriteLine("10. Возведение 3 в 7-ю степень");
            Console.WriteLine("11. Печать последовательностей");
            Console.WriteLine("12. Геометрическая прогрессия 1+1/x+1/x²+...+1/x¹⁰");
            Console.WriteLine("13. Кусочно-заданная функция");
            Console.WriteLine("14. Числа Фибоначчи (8 членов)");
            Console.WriteLine("15. 5-й член специальной последовательности");
            Console.WriteLine("16. Легенда о шахматной доске");
            Console.WriteLine("17. Расстояние до горизонта");
            Console.WriteLine("18. Размножение амеб");
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
                    case 11: Task11.Execute(); break;
                    case 12: Task12.Execute(); break;
                    case 13: Task13.Execute(); break;
                    case 14: Task14.Execute(); break;
                    case 15: Task15.Execute(); break;
                    case 16: Task16.Execute(); break;
                    case 17: Task17.Execute(); break;
                    case 18: Task18.Execute(); break;
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
