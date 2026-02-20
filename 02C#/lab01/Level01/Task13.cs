namespace Level1;

/// <summary>
/// Задача 13: Табулирование кусочно-заданной функции:
/// y = 1/(1-x), если x < 1
/// y = 1-x, если x = 1
/// y = x/(1-x), если x > 1
/// на отрезке [-1.5, 1.5] с шагом 0.1
/// </summary>
public static class Task13
{
    public static void Execute()
    {
        for (double x = -1.5; x <= 1.5 + 0.0001; x += 0.1)
        {
            double y;
            
            if (x < 1.0 - 0.0001)
            {
                y = 1.0 / (1.0 - x);
            }
            else if (Math.Abs(x - 1.0) < 0.0001)
            {
                y = 1.0 - x;
            }
            else
            {
                y = x / (1.0 - x);
            }
            
            Console.WriteLine($"{x,6:f1}\t\t{y,8:f4}");
        }
    }
}
