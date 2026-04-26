# СОДЕРЖИМОЕ ДЛЯ ОТЧЕТА LAB05
## Лабораторная работа №5: Механизмы наследования и полиморфизма в C#

---

## КЛАССЫ ПРЕДМЕТНОЙ ОБЛАСТИ

### 1. GeometricShape.cs - Абстрактный базовый класс

**Описание:** Базовый абстрактный класс для всех геометрических фигур. Демонстрирует инкапсуляцию (protected поля, public свойства), абстрактные методы для полиморфизма и виртуальный метод для расширения функциональности.

```csharp
using System;

namespace GeometryGUI
{
    public abstract class GeometricShape
    {
        protected double centerX;
        protected double centerY;
        protected string color;
        protected double size;
        protected string shapeName;

        public double CenterX
        {
            get { return centerX; }
            set { centerX = value; }
        }

        public double CenterY
        {
            get { return centerY; }
            set { centerY = value; }
        }

        public string Color
        {
            get { return color; }
            set { color = value; }
        }

        public double Size
        {
            get { return size; }
            set { size = value; }
        }

        public string ShapeName
        {
            get { return shapeName; }
        }

        public abstract double CalculateArea();
        public abstract void Draw();
        public abstract bool ContainsPoint(double x, double y);

        public virtual void SelectShape()
        {
            Console.WriteLine($"Фигура: {shapeName}");
            Console.WriteLine($"Площадь: {CalculateArea():F2}");
            Console.WriteLine($"Центр: ({centerX:F1}, {centerY:F1})");
            Console.WriteLine($"Размер: {size:F1}");
            Console.WriteLine($"Цвет: {color}");
        }
    }
}
```

**Ключевые моменты:**
- Модификатор `abstract` для класса и методов
- `protected` поля доступны наследникам
- `public` свойства обеспечивают инкапсуляцию
- Абстрактные методы (`CalculateArea`, `Draw`, `ContainsPoint`) должны быть реализованы в производных классах
- Виртуальный метод `SelectShape()` можно переопределить, но не обязательно

---

### 2. Square.cs - Класс квадрата

**Описание:** Производный класс для квадрата. Демонстрирует наследование, переопределение абстрактных методов, специфичную логику расчета площади (S = a²).

```csharp
using System;

namespace GeometryGUI
{
    public class Square : GeometricShape
    {
        public double Side => size;

        public Square(double centerX, double centerY, double side, string color)
        {
            this.centerX = centerX;
            this.centerY = centerY;
            this.size = side;
            this.color = color;
            this.shapeName = "Квадрат";
        }

        public override double CalculateArea()
        {
            return size * size;
        }

        public override void Draw()
        {
            Console.WriteLine($"□ {shapeName} - центр: ({centerX:F1}, {centerY:F1}), сторона: {size:F1}, цвет: {color}");
        }

        public override bool ContainsPoint(double x, double y)
        {
            double halfSide = size / 2;
            return Math.Abs(x - centerX) <= halfSide && Math.Abs(y - centerY) <= halfSide;
        }
    }
}
```

**Ключевые моменты:**
- Наследование: `: GeometricShape`
- `override` для реализации абстрактных методов
- Формула площади: S = a²
- Проверка точки: расстояние по X и Y не превышает половины стороны

---

### 3. Circle.cs - Класс круга

**Описание:** Производный класс для круга. Демонстрирует полиморфизм через разную реализацию методов (S = π·r²).

```csharp
using System;

namespace GeometryGUI
{
    public class Circle : GeometricShape
    {
        public double Diameter => size;

        public Circle(double centerX, double centerY, double diameter, string color)
        {
            this.centerX = centerX;
            this.centerY = centerY;
            this.size = diameter;
            this.color = color;
            this.shapeName = "Круг";
        }

        public override double CalculateArea()
        {
            double radius = size / 2;
            return Math.PI * radius * radius;
        }

        public override void Draw()
        {
            Console.WriteLine($"○ {shapeName} - центр: ({centerX:F1}, {centerY:F1}), диаметр: {size:F1}, цвет: {color}");
        }

        public override bool ContainsPoint(double x, double y)
        {
            double radius = size / 2;
            double distance = Math.Sqrt(Math.Pow(x - centerX, 2) + Math.Pow(y - centerY, 2));
            return distance <= radius;
        }
    }
}
```

**Ключевые моменты:**
- Формула площади: S = π·r²
- Проверка точки: евклидово расстояние от центра <= радиус
- Использование `Math.PI`, `Math.Sqrt`, `Math.Pow`

---

### 4. Triangle.cs - Класс треугольника

**Описание:** Производный класс для равностороннего треугольника. Формула площади: S = (a²·√3)/4.

```csharp
using System;

namespace GeometryGUI
{
    public class Triangle : GeometricShape
    {
        public double Height => size;

        public Triangle(double centerX, double centerY, double height, string color)
        {
            this.centerX = centerX;
            this.centerY = centerY;
            this.size = height;
            this.color = color;
            this.shapeName = "Треугольник";
        }

        public override double CalculateArea()
        {
            return (size * size * Math.Sqrt(3)) / 4;
        }

        public override void Draw()
        {
            Console.WriteLine($"△ {shapeName} - центр: ({centerX:F1}, {centerY:F1}), высота: {size:F1}, цвет: {color}");
        }

        public override bool ContainsPoint(double x, double y)
        {
            double radius = size / Math.Sqrt(3);
            double distance = Math.Sqrt(Math.Pow(x - centerX, 2) + Math.Pow(y - centerY, 2));
            return distance <= radius;
        }
    }
}
```

**Ключевые моменты:**
- Формула площади равностороннего треугольника: S = (a²·√3)/4
- Упрощенная проверка точки через описанную окружность

---

## ГРАФИЧЕСКИЙ ИНТЕРФЕЙС (Avalonia UI)

### 1. MainWindow.axaml - Разметка интерфейса

**Описание:** XAML-разметка главного окна. Grid из двух колонок: панель управления (250px) и Canvas для рисования.

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="GeometryGUI.Views.MainWindow"
        Title="Геометрические фигуры - ЛР5"
        Width="900" Height="700">

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- Левая панель управления -->
        <Border Grid.Column="0" BorderBrush="Gray" BorderThickness="0,0,2,0" Padding="10">
            <StackPanel>
                <TextBlock Text="Управление фигурами" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>
                
                <Button Name="CreateRandomButton" Content="Создать случайную фигуру" 
                       Width="220" Margin="0,0,0,10" Click="OnCreateRandomClick"/>
                
                <Button Name="ClearAllButton" Content="Очистить холст" 
                       Width="220" Margin="0,0,0,20" Click="OnClearAllClick"/>
                
                <TextBlock Text="Информация о фигуре" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                
                <Border BorderBrush="LightGray" BorderThickness="1" Padding="10" Margin="0,0,0,10">
                    <StackPanel>
                        <TextBlock Name="ShapeInfoLabel" Text="Выберите фигуру на холсте" 
                                  TextWrapping="Wrap" FontSize="12"/>
                    </StackPanel>
                </Border>
                
                <TextBlock Text="Проверка точки" FontSize="16" FontWeight="Bold" Margin="0,10,0,10"/>
                
                <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                    <TextBlock Text="X:" Width="30" VerticalAlignment="Center"/>
                    <TextBox Name="PointXTextBox" Width="80"/>
                </StackPanel>
                
                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                    <TextBlock Text="Y:" Width="30" VerticalAlignment="Center"/>
                    <TextBox Name="PointYTextBox" Width="80"/>
                </StackPanel>
                
                <Button Name="CheckPointButton" Content="Проверить точку" 
                       Width="220" Margin="0,0,0,10" Click="OnCheckPointClick"/>
                
                <TextBlock Name="PointResultLabel" Text="" TextWrapping="Wrap" 
                          FontSize="12" Foreground="DarkBlue" Margin="0,5,0,15"/>
                
                <Button Name="SaveButton" Content="Сохранить в файл" 
                       Width="220" Margin="0,0,0,10" Click="OnSaveClick"/>
                
                <Button Name="LoadButton" Content="Загрузить из файла" 
                       Width="220" Click="OnLoadClick"/>
                
                <TextBlock Name="StatusLabel" Text="" TextWrapping="Wrap" 
                          FontSize="11" Foreground="Green" Margin="0,10,0,0"/>
            </StackPanel>
        </Border>

        <!-- Правая панель с Canvas -->
        <Border Grid.Column="1" Background="White">
            <Canvas Name="DrawingCanvas" Background="White" 
                   PointerPressed="OnCanvasPointerPressed"/>
        </Border>
    </Grid>

</Window>
```

**Ключевые элементы:**
- `Grid` с двумя колонками для разделения интерфейса
- `Button` с обработчиками `Click="..."`
- `Canvas` для рисования фигур с событием `PointerPressed`
- `TextBox` для ввода координат
- `TextBlock` для вывода информации

---

### 2. MainWindow.axaml.cs - Логика приложения (Part 1 из 2)

**Описание:** Code-behind для главного окна. Управление коллекцией фигур, создание, отрисовка, взаимодействие с пользователем.

```csharp
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
```

**Ключевые моменты (Part 1):**
- `List<GeometricShape>` - полиморфная коллекция
- Создание случайных фигур через `switch` и базовый тип
- `DrawShape()` использует проверку типа (`is`) для отрисовки
- `OnCanvasPointerPressed()` демонстрирует полиморфизм: вызов `ContainsPoint()` на объектах разных типов

---

### 2. MainWindow.axaml.cs - Логика приложения (Part 2 из 2)

```csharp
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
```

**Ключевые моменты (Part 2):**
- Сохранение/загрузка фигур в текстовый файл
- Обработка исключений (`try-catch`)
- Работа с файлами через `StreamWriter`, `File.ReadAllLines`
- Pattern matching в `switch` expressions (ParseColor)

---

## ДЕМОНСТРАЦИЯ КОНЦЕПЦИЙ ООП

### 1. Наследование
```csharp
public class Square : GeometricShape { }    // Square наследует GeometricShape
public class Circle : GeometricShape { }    // Circle наследует GeometricShape
public class Triangle : GeometricShape { }  // Triangle наследует GeometricShape
```

### 2. Полиморфизм
```csharp
List<GeometricShape> shapes = new List<GeometricShape>();
shapes.Add(new Square(...));   // Добавляем квадрат как GeometricShape
shapes.Add(new Circle(...));   // Добавляем круг как GeometricShape
shapes.Add(new Triangle(...)); // Добавляем треугольник как GeometricShape

foreach (var shape in shapes)
{
    shape.CalculateArea();  // Вызывается конкретная реализация для каждого типа
}
```

### 3. Абстракция
```csharp
public abstract class GeometricShape
{
    public abstract double CalculateArea();      // Должен быть реализован
    public abstract void Draw();                 // Должен быть реализован
    public abstract bool ContainsPoint(...);     // Должен быть реализован
}
```

### 4. Инкапсуляция
```csharp
protected double centerX;  // Доступно только наследникам
public double CenterX      // Публичный доступ через свойство
{
    get { return centerX; }
    set { centerX = value; }
}
```

---

## МЕСТО ДЛЯ СКРИНШОТОВ

**Рекомендуемые скриншоты для отчета:**

### Скриншоты работы приложения:
1. **Начальное состояние** - пустой Canvas, левая панель управления
2. **Несколько фигур на холсте** - квадраты, круги, треугольники разных цветов
3. **Выбранная фигура** - информация о фигуре в левой панели (тип, центр, площадь, цвет)
4. **Проверка точки** - ввод координат и результат проверки (внутри/вне фигуры)
5. **Сохранение в файл** - сообщение "Сохранено N фигур"
6. **Загрузка из файла** - восстановление фигур после перезапуска

### Дополнительно (опционально):
7. Содержимое файла `shapes.txt` в текстовом редакторе
8. Демонстрация полиморфизма в отладчике (breakpoint в цикле `foreach`)

---

## ИНСТРУКЦИЯ ПО КОПИРОВАНИЮ В .PAGES

1. Откройте этот файл в текстовом редакторе или Markdown-просмотрщике
2. Скопируйте нужный раздел (например, "GeometricShape.cs")
3. Откройте ваш Lab05_Report_Kiryushin.pages
4. Вставьте код в соответствующий раздел отчета
5. Примените форматирование кода (моноширинный шрифт, например Menlo или Courier)
6. Добавьте скриншоты в раздел "МЕСТО ДЛЯ СКРИНШОТОВ"
7. Убедитесь, что титульный слайд не изменен

---

**Дата создания документа:** 26 апреля 2026
**Версия:** 1.0
