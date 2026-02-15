namespace Level1;

/// <summary>
/// Задача 15: Вычислить 5-й член последовательности 1/1, 2/1, 3/2, 5/3, 8/5, ...
/// Числитель и знаменатель следующего члена получаются сложением
/// числителей и знаменателей двух предыдущих
/// </summary>
public static class Task15
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 15: 5-й член специальной последовательности ===\n");
        
        int num1 = 1, den1 = 1;  // 1-й член: 1/1
        int num2 = 2, den2 = 1;  // 2-й член: 2/1
        
        Console.WriteLine($"1-й член: {num1}/{den1} = {(double)num1/den1:f4}");
        Console.WriteLine($"2-й член: {num2}/{den2} = {(double)num2/den2:f4}");
        
        int numNext = 0, denNext = 0;
        
        for (int i = 3; i <= 5; i++)
        {
            numNext = num1 + num2;
            denNext = den1 + den2;
            Console.WriteLine($"{i}-й член: {numNext}/{denNext} = {(double)numNext/denNext:f4}");
            
            num1 = num2;
            den1 = den2;
            num2 = numNext;
            den2 = denNext;
        }
        
        Console.WriteLine($"\n5-й член последовательности: {numNext}/{denNext} = {(double)numNext/denNext:f6}");
    }
}
