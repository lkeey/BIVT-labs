using System;

namespace GeometryApp
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
