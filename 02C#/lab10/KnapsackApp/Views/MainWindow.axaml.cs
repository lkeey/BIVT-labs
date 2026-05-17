using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using KnapsackApp.Services;
using KnapsackApp.ViewModels;
using ScottPlot;

namespace KnapsackApp.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        
        var vm = new MainWindowViewModel();
        DataContext = vm;

        vm.OnBenchmarksCompleted = DrawChart;
    }

    private void DrawChart(List<BenchmarkResult> results)
    {
        Avalonia.Threading.Dispatcher.UIThread.Post(() =>
        {
            AvaPlot1.Plot.Clear();

            double[] xs = results.Select(r => (double)r.Threads).ToArray();
            double[] yParallelFor = results.Select(r => (double)r.ParallelForTimeMs).ToArray();
            double[] yThreads = results.Select(r => (double)r.ThreadsTimeMs).ToArray();

            // Идеальное ускорение (Время 1 потока / N)
            double baseTime = yParallelFor[0]; // Берем время 1 потока Parallel.For за базу
            double[] yIdeal = xs.Select(x => baseTime / x).ToArray();

            var scatter1 = AvaPlot1.Plot.Add.Scatter(xs, yParallelFor);
            scatter1.LegendText = "Parallel.For";
            scatter1.LineWidth = 2;
            scatter1.MarkerSize = 7;

            var scatter2 = AvaPlot1.Plot.Add.Scatter(xs, yThreads);
            scatter2.LegendText = "Сырые потоки (Thread)";
            scatter2.LineWidth = 2;
            scatter2.MarkerSize = 7;

            var scatter3 = AvaPlot1.Plot.Add.Scatter(xs, yIdeal);
            scatter3.LegendText = "Идеальное ускорение";
            scatter3.LineWidth = 2;
            scatter3.LinePattern = LinePattern.Dashed;
            scatter3.MarkerSize = 0;

            AvaPlot1.Plot.Title("Масштабируемость алгоритма (Задача о рюкзаке, 25 предметов)");
            AvaPlot1.Plot.XLabel("Количество потоков");
            AvaPlot1.Plot.YLabel("Время выполнения (мс)");
            
            AvaPlot1.Plot.Axes.AutoScale(); // Добавлено авто-масштабирование осей
        AvaPlot1.Plot.ShowLegend();
        AvaPlot1.UserInputProcessor.Disable(); // Отключаем зум и скролл
        AvaPlot1.Refresh();
        });
    }
}