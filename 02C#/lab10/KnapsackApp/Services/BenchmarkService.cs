using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using KnapsackApp.Models;

namespace KnapsackApp.Services;

public class BenchmarkResult
{
    public int Threads { get; set; }
    public long ParallelForTimeMs { get; set; }
    public long ThreadsTimeMs { get; set; }
}

public class BenchmarkService
{
    public static async Task<List<BenchmarkResult>> RunBenchmarksAsync(Item[] items, int maxWeight, int[] threadCounts, Action<string> logAction)
    {
        return await Task.Run(() =>
        {
            var solver = new KnapsackSolver(items, maxWeight);
            var results = new List<BenchmarkResult>();

            logAction("Выполняется прогрев (JIT warmup)...");
            // Прогрев на 1 потоке
            solver.SolveParallelFor(1);
            solver.SolveThreads(1);
            logAction("Прогрев завершен.\n");

            // Оценка последовательного времени для идеального ускорения
            logAction("Запуск последовательного алгоритма...");
            var sw = Stopwatch.StartNew();
            var seqResult = solver.SolveSequential();
            sw.Stop();
            long seqTime = sw.ElapsedMilliseconds;
            logAction($"Последовательный алгоритм: {seqTime} мс. Макс. ценность: {seqResult.MaxValue}\n");

            foreach (int threads in threadCounts)
            {
                logAction($"Тестирование для {threads} потоков...");
                
                // Parallel.For
                sw.Restart();
                var pResult = solver.SolveParallelFor(threads);
                sw.Stop();
                long pTime = sw.ElapsedMilliseconds;
                logAction($"  Parallel.For: {pTime} мс");

                // Threads
                sw.Restart();
                var tResult = solver.SolveThreads(threads);
                sw.Stop();
                long tTime = sw.ElapsedMilliseconds;
                logAction($"  Threads: {tTime} мс\n");

                results.Add(new BenchmarkResult
                {
                    Threads = threads,
                    ParallelForTimeMs = pTime,
                    ThreadsTimeMs = tTime
                });
            }

            return results;
        });
    }
}