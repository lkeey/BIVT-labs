using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using KnapsackApp.Models;

namespace KnapsackApp.Services;

public class KnapsackSolver
{
    private readonly Item[] _items;
    private readonly int _maxWeight;
    private readonly int _totalCombinations;

    public KnapsackSolver(Item[] items, int maxWeight)
    {
        _items = items;
        _maxWeight = maxWeight;
        _totalCombinations = 1 << items.Length;
    }

    public KnapsackResult SolveSequential()
    {
        int maxValue = 0;
        int bestCombination = 0;
        int bestWeight = 0;

        for (int i = 0; i < _totalCombinations; i++)
        {
            int currentWeight = 0;
            int currentValue = 0;

            for (int j = 0; j < _items.Length; j++)
            {
                if ((i & (1 << j)) != 0)
                {
                    currentWeight += _items[j].Weight;
                    currentValue += _items[j].Value;
                }
            }

            if (currentWeight <= _maxWeight && currentValue > maxValue)
            {
                maxValue = currentValue;
                bestCombination = i;
                bestWeight = currentWeight;
            }
        }

        return new KnapsackResult { MaxValue = maxValue, BestCombination = bestCombination, TotalWeight = bestWeight };
    }

    public KnapsackResult SolveParallelFor(int maxDegreeOfParallelism)
    {
        int globalMaxValue = 0;
        int globalBestCombination = 0;
        int globalBestWeight = 0;

        var options = new ParallelOptions { MaxDegreeOfParallelism = maxDegreeOfParallelism };

        Parallel.For(0, _totalCombinations, options,
            () => new KnapsackResult { MaxValue = 0, BestCombination = 0, TotalWeight = 0 },
            (i, state, localResult) =>
            {
                int currentWeight = 0;
                int currentValue = 0;

                for (int j = 0; j < _items.Length; j++)
                {
                    if ((i & (1 << j)) != 0)
                    {
                        currentWeight += _items[j].Weight;
                        currentValue += _items[j].Value;
                    }
                }

                if (currentWeight <= _maxWeight && currentValue > localResult.MaxValue)
                {
                    localResult.MaxValue = currentValue;
                    localResult.BestCombination = i;
                    localResult.TotalWeight = currentWeight;
                }

                return localResult;
            },
            localResult =>
            {
                lock (this)
                {
                    if (localResult.MaxValue > globalMaxValue)
                    {
                        globalMaxValue = localResult.MaxValue;
                        globalBestCombination = localResult.BestCombination;
                        globalBestWeight = localResult.TotalWeight;
                    }
                }
            });

        return new KnapsackResult { MaxValue = globalMaxValue, BestCombination = globalBestCombination, TotalWeight = globalBestWeight };
    }

    public KnapsackResult SolveThreads(int numThreads)
    {
        int globalMaxValue = 0;
        int globalBestCombination = 0;
        int globalBestWeight = 0;
        object locker = new object();

        Thread[] threads = new Thread[numThreads];
        int chunkSize = _totalCombinations / numThreads;
        int remainder = _totalCombinations % numThreads;

        int startIdx = 0;

        for (int t = 0; t < numThreads; t++)
        {
            int start = startIdx;
            int end = start + chunkSize + (t < remainder ? 1 : 0);
            startIdx = end;

            threads[t] = new Thread(() =>
            {
                int localMaxValue = 0;
                int localBestCombination = 0;
                int localBestWeight = 0;

                for (int i = start; i < end; i++)
                {
                    int currentWeight = 0;
                    int currentValue = 0;

                    for (int j = 0; j < _items.Length; j++)
                    {
                        if ((i & (1 << j)) != 0)
                        {
                            currentWeight += _items[j].Weight;
                            currentValue += _items[j].Value;
                        }
                    }

                    if (currentWeight <= _maxWeight && currentValue > localMaxValue)
                    {
                        localMaxValue = currentValue;
                        localBestCombination = i;
                        localBestWeight = currentWeight;
                    }
                }

                lock (locker)
                {
                    if (localMaxValue > globalMaxValue)
                    {
                        globalMaxValue = localMaxValue;
                        globalBestCombination = localBestCombination;
                        globalBestWeight = localBestWeight;
                    }
                }
            });
            threads[t].Start();
        }

        foreach (var thread in threads)
        {
            thread.Join();
        }

        return new KnapsackResult { MaxValue = globalMaxValue, BestCombination = globalBestCombination, TotalWeight = globalBestWeight };
    }
}