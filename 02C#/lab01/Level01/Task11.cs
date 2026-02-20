namespace Level1;

/// <summary>
/// Задача 11: Напечатать заданные последовательности чисел
/// а) 1 2 3 4 5 6
/// б) 5 5 5 5 5 5
/// </summary>
public static class Task11
{
    public static void Execute()
    {
        
        Console.Write("а) ");
        for (int i = 1; i <= 6; i++)
        {
            Console.Write($"{i} ");
        }
        Console.WriteLine();
        
        Console.Write("б) ");
        for (int i = 1; i <= 6; i++)
        {
            Console.Write("5 ");
        }
        Console.WriteLine();
    }
}
