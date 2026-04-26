using System;

namespace GeometryApp
{
    public class Triangle : GeometricShape
    {
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
