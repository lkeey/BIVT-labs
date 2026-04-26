using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace GeometryApp
{
    class Program
    {
        private static List<GeometricShape> shapes = new List<GeometricShape>();
        private static Random random = new Random();
        private static string[] colors = { "Красный", "Синий", "Зеленый", "Желтый", "Оранжевый", "Фиолетовый", "Розовый" };

        static void Main(string[] args)
        {
            Console.OutputEncoding = System.Text.Encoding.UTF8;

            Console.WriteLine("====================================================");
            Console.WriteLine("  ГЕОМЕТРИЧЕСКИЕ ФИГУРЫ - ЛАБОРАТОРНАЯ РАБОТА №5");
            Console.WriteLine("====================================================");
            Console.WriteLine();

            while (true)
            {
                Console.WriteLine();
                Console.WriteLine("==================== МЕНЮ ====================");
                Console.WriteLine("1. Создать новую фигуру (случайного типа)");
                Console.WriteLine("2. Показать все фигуры");
                Console.WriteLine("3. Выбрать фигуру (по номеру)");
                Console.WriteLine("4. Проверить точку на принадлежность");
                Console.WriteLine("5. Сохранить фигуры в файл");
                Console.WriteLine("6. Загрузить фигуры из файла");
                Console.WriteLine("0. Выход");
                Console.WriteLine("==============================================");
                Console.Write("Выберите действие: ");

                string choice = Console.ReadLine();
                Console.WriteLine();

                switch (choice)
                {
                    case "1":
                        CreateRandomShape();
                        break;
                    case "2":
                        ShowAllShapes();
                        break;
                    case "3":
                        SelectShape();
                        break;
                    case "4":
                        CheckPoint();
                        break;
                    case "5":
                        SaveToFile();
                        break;
                    case "6":
                        LoadFromFile();
                        break;
                    case "0":
                        Console.WriteLine("Программа завершена.");
                        return;
                    default:
                        Console.WriteLine("Неверный выбор. Попробуйте снова.");
                        break;
                }
            }
        }

        static void CreateRandomShape()
        {
            int shapeType = random.Next(0, 3);
            double centerX = random.Next(10, 200);
            double centerY = random.Next(10, 200);
            double size = random.Next(10, 50);
            string color = colors[random.Next(colors.Length)];

            GeometricShape shape = null;

            switch (shapeType)
            {
                case 0:
                    shape = new Square(centerX, centerY, size, color);
                    break;
                case 1:
                    shape = new Circle(centerX, centerY, size, color);
                    break;
                case 2:
                    shape = new Triangle(centerX, centerY, size, color);
                    break;
            }

            if (shape != null)
            {
                shapes.Add(shape);
                Console.WriteLine($"Создана фигура #{shapes.Count}:");
                shape.Draw();
                Console.WriteLine($"Площадь: {shape.CalculateArea():F2}");
            }
        }

        static void ShowAllShapes()
        {
            if (shapes.Count == 0)
            {
                Console.WriteLine("Список фигур пуст.");
                return;
            }

            Console.WriteLine("==================== ФИГУРЫ В СПИСКЕ ====================");
            for (int i = 0; i < shapes.Count; i++)
            {
                Console.Write($"{i + 1}. ");
                shapes[i].Draw();
                Console.WriteLine($"   Площадь: {shapes[i].CalculateArea():F2}");
            }
            Console.WriteLine("=========================================================");
        }

        static void SelectShape()
        {
            if (shapes.Count == 0)
            {
                Console.WriteLine("Список фигур пуст.");
                return;
            }

            Console.Write($"Введите номер фигуры (1-{shapes.Count}): ");
            if (int.TryParse(Console.ReadLine(), out int index) && index >= 1 && index <= shapes.Count)
            {
                Console.WriteLine();
                Console.WriteLine("==================== ИНФОРМАЦИЯ О ФИГУРЕ ====================");
                shapes[index - 1].SelectShape();
                Console.WriteLine("=============================================================");
            }
            else
            {
                Console.WriteLine("Неверный номер фигуры.");
            }
        }

        static void CheckPoint()
        {
            if (shapes.Count == 0)
            {
                Console.WriteLine("Список фигур пуст.");
                return;
            }

            Console.Write("Введите координату X: ");
            if (!double.TryParse(Console.ReadLine(), out double x))
            {
                Console.WriteLine("Ошибка ввода.");
                return;
            }

            Console.Write("Введите координату Y: ");
            if (!double.TryParse(Console.ReadLine(), out double y))
            {
                Console.WriteLine("Ошибка ввода.");
                return;
            }

            Console.WriteLine();
            Console.WriteLine($"Проверка точки ({x:F1}, {y:F1}):");
            bool found = false;

            for (int i = 0; i < shapes.Count; i++)
            {
                if (shapes[i].ContainsPoint(x, y))
                {
                    Console.WriteLine($"  Фигура #{i + 1} ({shapes[i].ShapeName}) содержит эту точку");
                    found = true;
                }
            }

            if (!found)
            {
                Console.WriteLine("  Точка не принадлежит ни одной фигуре");
            }
        }

        static void SaveToFile()
        {
            if (shapes.Count == 0)
            {
                Console.WriteLine("Список фигур пуст. Нечего сохранять.");
                return;
            }

            string filename = "shapes.txt";

            try
            {
                using (StreamWriter writer = new StreamWriter(filename))
                {
                    foreach (var shape in shapes)
                    {
                        string type = shape.GetType().Name;
                        writer.WriteLine($"{type};{shape.Color};{shape.CenterX};{shape.CenterY};{shape.Size}");
                    }
                }
                Console.WriteLine($"Сохранено {shapes.Count} фигур в файл '{filename}'");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при сохранении: {ex.Message}");
            }
        }

        static void LoadFromFile()
        {
            string filename = "shapes.txt";

            if (!File.Exists(filename))
            {
                Console.WriteLine($"Файл '{filename}' не найден.");
                return;
            }

            try
            {
                shapes.Clear();
                string[] lines = File.ReadAllLines(filename);

                foreach (string line in lines)
                {
                    string[] parts = line.Split(';');
                    if (parts.Length != 5) continue;

                    string type = parts[0];
                    string color = parts[1];
                    double centerX = double.Parse(parts[2]);
                    double centerY = double.Parse(parts[3]);
                    double size = double.Parse(parts[4]);

                    GeometricShape shape = null;

                    switch (type)
                    {
                        case "Square":
                            shape = new Square(centerX, centerY, size, color);
                            break;
                        case "Circle":
                            shape = new Circle(centerX, centerY, size, color);
                            break;
                        case "Triangle":
                            shape = new Triangle(centerX, centerY, size, color);
                            break;
                    }

                    if (shape != null)
                    {
                        shapes.Add(shape);
                    }
                }

                Console.WriteLine($"Загружено {shapes.Count} фигур из файла '{filename}'");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при загрузке: {ex.Message}");
            }
        }
    }
}
