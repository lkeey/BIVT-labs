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
