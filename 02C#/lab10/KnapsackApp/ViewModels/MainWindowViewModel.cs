using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using KnapsackApp.Models;
using KnapsackApp.Services;

namespace KnapsackApp.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    [ObservableProperty]
    private string _logs = string.Empty;

    [ObservableProperty]
    private bool _isBusy;

    public Action<List<BenchmarkResult>>? OnBenchmarksCompleted;

    [RelayCommand]
    public async Task StartBenchmarkAsync()
    {
        IsBusy = true;
        Logs = "Генерация предметов...\n";

        var rand = new Random(42); // Фиксированный сид для повторяемости
        var items = new Item[25];
        for (int i = 0; i < 25; i++)
        {
            items[i] = new Item
            {
                Weight = rand.Next(1, 6),
                Value = rand.Next(1, 101)
            };
        }

        Logs += "Предметы сгенерированы (25 шт).\n\n";

        int[] threadCounts = { 1, 2, 4, 8, 12, 16 };
        
        var results = await BenchmarkService.RunBenchmarksAsync(items, 50, threadCounts, msg =>
        {
            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                Logs += msg + "\n";
            });
        });

        OnBenchmarksCompleted?.Invoke(results);
        IsBusy = false;
    }
}