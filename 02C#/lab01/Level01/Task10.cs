namespace Level1;

/// <summary>
/// Задача 10: Возвести число 3 в 7-ю степень без операции возведения в степень
/// </summary>
public static class Task10
{
    public static void Execute()
    {        
        int result = 1;
        int baseNum = 3;
        int power = 7;
                
        for (int i = 0; i < power; i++)
        {
            result *= baseNum;
        }
        
        Console.WriteLine($" = {result}");
    }
}
