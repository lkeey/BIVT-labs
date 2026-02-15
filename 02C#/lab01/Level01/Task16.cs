namespace Level1;

/// <summary>
/// Задача 16: Легенда о шахматной доске
/// На каждую следующую клетку в два раза больше зерен: 1, 2, 4, 8, ...
/// Определить общее количество зерна на доске (64 клетки)
/// Считать, что в 1 грамме 15 зерен
/// </summary>
public static class Task16
{
    public static void Execute()
    {
        Console.WriteLine("=== Задача 16: Легенда о шахматной доске ===\n");
        
        ulong totalGrains = 0;
        ulong grainsOnCell = 1;
        
        for (int cell = 1; cell <= 64; cell++)
        {
            totalGrains += grainsOnCell;
            
            if (cell <= 10 || cell > 60)
            {
                Console.WriteLine($"Клетка {cell,2}: {grainsOnCell,20:N0} зерен");
            }
            else if (cell == 11)
            {
                Console.WriteLine("...");
            }
            
            grainsOnCell *= 2;
        }
        
        double gramsPerGrain = 1.0 / 15.0;
        double totalGrams = totalGrains * gramsPerGrain;
        double totalKg = totalGrams / 1000.0;
        double totalTonnes = totalKg / 1000.0;
        
        Console.WriteLine($"\nВсего зерен: {totalGrains:N0}");
        Console.WriteLine($"Масса в граммах: {totalGrams:E2} г");
        Console.WriteLine($"Масса в килограммах: {totalKg:E2} кг");
        Console.WriteLine($"Масса в тоннах: {totalTonnes:E2} т");
        Console.WriteLine($"\nТочность: расчет выполнен с использованием ulong (64-битное целое число)");
    }
}
