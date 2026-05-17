namespace KnapsackApp.Models;

public class Item
{
    public int Weight { get; set; }
    public int Value { get; set; }
}

public class KnapsackResult
{
    public int MaxValue { get; set; }
    public int BestCombination { get; set; }
    public int TotalWeight { get; set; }
}