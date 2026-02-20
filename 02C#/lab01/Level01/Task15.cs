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
        
        int num1 = 1, den1 = 1;  
        int num2 = 2, den2 = 1;  
        int numNext = 0, denNext = 0;
        
        for (int i = 3; i <= 5; i++)
        {
            numNext = num1 + num2;
            denNext = den1 + den2;
            
            num1 = num2;
            den1 = den2;
            num2 = numNext;
            den2 = denNext;
        }
        
        Console.WriteLine($"\n5-й член последовательности: {numNext}/{denNext} = {(double)numNext/denNext:f6}");
    }
}
