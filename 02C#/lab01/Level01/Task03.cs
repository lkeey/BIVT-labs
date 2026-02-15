namespace Level1;

/// <summary>
/// Задача 3: Вычислить s = 2/3 + 4/5 + 6/7 + ... + 112/113
/// </summary>
public static class Task03
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 3: Сумма s = 2/3 + 4/5 + 6/7 + ... + 112/113 ===\n");
        
        double sum = 0;
        int count = 0;
        
        for (int numerator = 2; numerator <= 112; numerator += 2)
        {
            int denominator = numerator + 1;
            double term = (double)numerator / denominator;
            sum += term;
            count++;
            
            if (count <= 5 || numerator >= 108)
            {
                Console.WriteLine($"{numerator}/{denominator} = {term:f4}");
            }
            else if (count == 6)
            {
                Console.WriteLine("...");
            }
        }
        
        Console.WriteLine($"\nСумма s = {sum:f4}");
    }
}
