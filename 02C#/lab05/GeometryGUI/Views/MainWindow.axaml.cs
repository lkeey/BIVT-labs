using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace GeometryGUI.Views
{
    public partial class MainWindow : Window
    {
        private List<GeometricShape> shapes = new List<GeometricShape>();
        private GeometricShape? selectedShape = null;
        private Random random = new Random();
        private string[] colors = { "Red", "Blue", "Green", "Orange", "Purple", "Brown", "Pink", "Cyan" };

        public MainWindow()
        {
            InitializeComponent();
        }

        private void OnCreateRandomClick(object? sender, RoutedEventArgs e)
        {
            double canvasWidth = DrawingCanvas.Bounds.Width;
            double canvasHeight = DrawingCanvas.Bounds.Height;

            if (canvasWidth <= 0 || canvasHeight <= 0)
            {
                canvasWidth = 600;
                canvasHeight = 600;
            }

            int shapeType = random.Next(0, 3);
            double centerX = random.Next(100, (int)canvasWidth - 100);
            double centerY = random.Next(100, (int)canvasHeight - 100);
            string color = colors[random.Next(colors.Length)];

            GeometricShape shape;
            switch (shapeType)
            {
                case 0:
                    double side = random.Next(30, 100);
                    shape = new Square(centerX, centerY, side, color);
                    break;
                case 1:
                    double diameter = random.Next(40, 120);
                    shape = new Circle(centerX, centerY, diameter, color);
                    break;
                default:
                    double height = random.Next(40, 100);
                    shape = new Triangle(centerX, centerY, height, color);
                    break;
            }

            shapes.Add(shape);
            DrawShape(shape);
            StatusLabel.Text = $"Создана фигура: {shape.GetType().Name}";
        }

        private void DrawShape(GeometricShape shape)
        {
            Shape visual;
            IBrush brush = new SolidColorBrush(ParseColor(shape.Color));
            IBrush stroke = Brushes.Black;

            if (shape is Square square)
            {
                visual = new Rectangle
                {
                    Width = square.Side,
                    Height = square.Side,
                    Fill = brush,
                    Stroke = stroke,
                    StrokeThickness = 2
                };
                Canvas.SetLeft(visual, shape.CenterX - square.Side / 2);
                Canvas.SetTop(visual, shape.CenterY - square.Side / 2);
            }
            else if (shape is Circle circle)
            {
                visual = new Ellipse
                {
                    Width = circle.Diameter,
                    Height = circle.Diameter,
                    Fill = brush,
                    Stroke = stroke,
                    StrokeThickness = 2
                };
                Canvas.SetLeft(visual, shape.CenterX - circle.Diameter / 2);
                Canvas.SetTop(visual, shape.CenterY - circle.Diameter / 2);
            }
            else if (shape is Triangle triangle)
            {
                double halfBase = triangle.Height / 2;
                Polygon polygon = new Polygon
                {
                    Fill = brush,
                    Stroke = stroke,
                    StrokeThickness = 2,
                    Points = new Avalonia.Collections.AvaloniaList<Avalonia.Point>
                    {
                        new Avalonia.Point(0, -triangle.Height * 2.0 / 3.0),
                        new Avalonia.Point(-halfBase, triangle.Height / 3.0),
                        new Avalonia.Point(halfBase, triangle.Height / 3.0)
                    }
                };
                visual = polygon;
                Canvas.SetLeft(visual, shape.CenterX);
                Canvas.SetTop(visual, shape.CenterY);
            }
            else
            {
                return;
            }

            visual.Tag = shape;
            DrawingCanvas.Children.Add(visual);
        }

        private void OnCanvasPointerPressed(object? sender, PointerPressedEventArgs e)
        {
            var point = e.GetPosition(DrawingCanvas);
            double x = point.X;
            double y = point.Y;

            selectedShape = null;
            foreach (var shape in shapes)
            {
                if (shape.ContainsPoint(x, y))
                {
                    selectedShape = shape;
                    break;
                }
            }

            if (selectedShape != null)
            {
                ShapeInfoLabel.Text = $"Тип: {selectedShape.GetType().Name}\n" +
                                     $"Центр: ({selectedShape.CenterX:F1}, {selectedShape.CenterY:F1})\n" +
                                     $"Цвет: {selectedShape.Color}\n" +
                                     $"Площадь: {selectedShape.CalculateArea():F2}";
                selectedShape.SelectShape();
            }
            else
            {
                ShapeInfoLabel.Text = "Выберите фигуру на холсте";
            }
        }

        private void OnCheckPointClick(object? sender, RoutedEventArgs e)
        {
            if (!double.TryParse(PointXTextBox.Text, out double x) ||
                !double.TryParse(PointYTextBox.Text, out double y))
            {
                PointResultLabel.Text = "Ошибка: введите корректные координаты";
                PointResultLabel.Foreground = Brushes.Red;
                return;
            }

            if (selectedShape == null)
            {
                PointResultLabel.Text = "Выберите фигуру на холсте";
                PointResultLabel.Foreground = Brushes.Orange;
                return;
            }

            bool inside = selectedShape.ContainsPoint(x, y);
            PointResultLabel.Text = inside
                ? $"Точка ({x:F1}, {y:F1}) ВНУТРИ выбранной фигуры"
                : $"Точка ({x:F1}, {y:F1}) ВНЕ выбранной фигуры";
            PointResultLabel.Foreground = inside ? Brushes.Green : Brushes.Red;
        }

        private void OnClearAllClick(object? sender, RoutedEventArgs e)
        {
            shapes.Clear();
            DrawingCanvas.Children.Clear();
            selectedShape = null;
            ShapeInfoLabel.Text = "Выберите фигуру на холсте";
            StatusLabel.Text = "Холст очищен";
        }

        private void OnSaveClick(object? sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = "shapes.txt";
                using (StreamWriter writer = new StreamWriter(filePath))
                {
                    foreach (var shape in shapes)
                    {
                        if (shape is Square square)
                        {
                            writer.WriteLine($"Square|{square.CenterX}|{square.CenterY}|{square.Side}|{square.Color}");
                        }
                        else if (shape is Circle circle)
                        {
                            writer.WriteLine($"Circle|{circle.CenterX}|{circle.CenterY}|{circle.Diameter}|{circle.Color}");
                        }
                        else if (shape is Triangle triangle)
                        {
                            writer.WriteLine($"Triangle|{triangle.CenterX}|{triangle.CenterY}|{triangle.Height}|{triangle.Color}");
                        }
                    }
                }
                StatusLabel.Text = $"Сохранено {shapes.Count} фигур в файл {filePath}";
                StatusLabel.Foreground = Brushes.Green;
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Ошибка сохранения: {ex.Message}";
                StatusLabel.Foreground = Brushes.Red;
            }
        }

        private void OnLoadClick(object? sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = "shapes.txt";
                if (!File.Exists(filePath))
                {
                    StatusLabel.Text = "Файл shapes.txt не найден";
                    StatusLabel.Foreground = Brushes.Orange;
                    return;
                }

                shapes.Clear();
                DrawingCanvas.Children.Clear();

                string[] lines = File.ReadAllLines(filePath);
                foreach (string line in lines)
                {
                    string[] parts = line.Split('|');
                    if (parts.Length < 5) continue;

                    string type = parts[0];
                    double centerX = double.Parse(parts[1]);
                    double centerY = double.Parse(parts[2]);
                    double size = double.Parse(parts[3]);
                    string color = parts[4];

                    GeometricShape shape;
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
                        default:
                            continue;
                    }

                    shapes.Add(shape);
                    DrawShape(shape);
                }

                StatusLabel.Text = $"Загружено {shapes.Count} фигур из файла {filePath}";
                StatusLabel.Foreground = Brushes.Green;
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Ошибка загрузки: {ex.Message}";
                StatusLabel.Foreground = Brushes.Red;
            }
        }

        private Color ParseColor(string colorName)
        {
            return colorName.ToLower() switch
            {
                "red" => Colors.Red,
                "blue" => Colors.Blue,
                "green" => Colors.Green,
                "orange" => Colors.Orange,
                "purple" => Colors.Purple,
                "brown" => Colors.Brown,
                "pink" => Colors.Pink,
                "cyan" => Colors.Cyan,
                _ => Colors.Gray
            };
        }
    }
}
