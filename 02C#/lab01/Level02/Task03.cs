namespace Level2;

/// <summary>
/// Задача 3: Определить количество членов арифметической прогрессии
/// s = a + (a+h) + ... + (a+nh), сумма которых не превышает заданного числа p
/// </summary>
public static class Task03
{
    public static void Execute()
    {        
        Console.Write("Введите начальное значение a: ");
        double a = double.Parse(Console.ReadLine() ?? "2.0");
        
        Console.Write("Введите шаг h: ");
        double h = double.Parse(Console.ReadLine() ?? "3.0");
        
        Console.Write("Введите предельное значение суммы p: ");
        double p = double.Parse(Console.ReadLine() ?? "50.0");
        
        double sum = 0;
        int n = 0;
        double member;
        
        Console.WriteLine($"\na={a}, h={h}, p={p}\n");
        
        do
        {
            member = a + n * h;
            sum += member;
            n++;
        }
        while (sum <= p);
        
        n--; // возврат к последнему подходящему значению
        sum -= (a + n * h); // вычитаем последний член
        
        Console.WriteLine($"\nКоличество членов, не превышающих сумму {p}: {n}");
        Console.WriteLine($"Сумма первых {n} членов: {sum:f2}");
    }
}
