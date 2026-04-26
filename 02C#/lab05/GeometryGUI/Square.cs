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
