using TradingSimulatorAPI.Models;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Utils;

public static class CalculationUtils
{
    /// <summary>
    /// Calculates Simple Moving Average (SMA).
    /// </summary>
    /// <param name="data">List of data points (usually close prices).</param>
    /// <param name="window">The period window size.</param>
    /// <returns>A list of nullable doubles representing the SMA. Null if SMA cannot be calculated for a point.</returns>
    public static List<double?> CalculateSMA(List<decimal> data, int window)
    {
        if (window <= 0 || data == null || data.Count < window)
        {
            return Enumerable.Repeat<double?>(null, data?.Count ?? 0).ToList();
        }

        var sma = new List<double?>(data.Count);
        // Fill initial points where SMA cannot be calculated with null
        for (int i = 0; i < window - 1; i++)
        {
            sma.Add(null);
        }

        decimal currentSum = data.Take(window).Sum();
        sma.Add((double)(currentSum / window));

        for (int i = window; i < data.Count; i++)
        {
            currentSum = currentSum - data[i - window] + data[i];
            sma.Add((double)(currentSum / window));
        }
        return sma;
    }

     /// <summary>
    /// Calculates Relative Strength Index (RSI) using Simple Moving Average for gains/losses.
    /// </summary>
    /// <param name="data">List of data points (usually close prices).</param>
    /// <param name="window">The period window size (typically 14).</param>
    /// <returns>A list of nullable doubles representing the RSI. Null if RSI cannot be calculated.</returns>
    public static List<double?> CalculateRSI(List<decimal> data, int window)
    {
        if (window <= 0 || data == null || data.Count <= window) // Need at least window+1 points for first RSI value
        {
            return Enumerable.Repeat<double?>(null, data?.Count ?? 0).ToList();
        }

        var rsi = new List<double?>(data.Count);
        var gains = new List<decimal>(data.Count);
        var losses = new List<decimal>(data.Count);

        // Calculate initial gains and losses
        gains.Add(0); // First element has no change
        losses.Add(0);
        for (int i = 1; i < data.Count; i++)
        {
            decimal change = data[i] - data[i - 1];
            gains.Add(Math.Max(0, change));
            losses.Add(Math.Max(0, -change));
        }

        // Calculate initial average gain and loss (using SMA for simplicity)
        decimal avgGain = gains.Skip(1).Take(window).Sum() / window;
        decimal avgLoss = losses.Skip(1).Take(window).Sum() / window;

        // Fill initial points where RSI cannot be calculated
        for (int i = 0; i <= window; i++) // RSI value is available at index `window` (needs `window` changes)
        {
            rsi.Add(null);
        }

        // Calculate first RSI value
         if (avgLoss == 0)
         {
             rsi[window] = 100.0; // Avoid division by zero; price consistently rose
         }
         else
         {
             decimal rs = avgGain / avgLoss;
             rsi[window] = (double)(100m - (100m / (1m + rs)));
         }


        // Calculate subsequent RSI values using Wilder's smoothing (approximation using SMA here for simplicity)
        // For a more accurate Wilder's smoothing:
        // AvgGain = ((PrevAvgGain * (window - 1)) + CurrentGain) / window
        // AvgLoss = ((PrevAvgLoss * (window - 1)) + CurrentLoss) / window
        for (int i = window + 1; i < data.Count; i++)
        {
            // Simple Moving Average approach for average gain/loss update:
             avgGain = gains.Skip(i - window).Take(window).Sum() / window;
             avgLoss = losses.Skip(i - window).Take(window).Sum() / window;

            if (avgLoss == 0)
            {
                rsi.Add(100.0); // Price consistently rose or stayed flat
            }
            else
            {
                decimal rs = avgGain / avgLoss;
                rsi.Add((double)(100m - (100m / (1m + rs))));
            }
        }
         // Pad the end if necessary (shouldn't be needed if loop goes to data.Count)
        // while (rsi.Count < data.Count) { rsi.Add(null); }

        return rsi;
    }


    /// <summary>
    /// Calculates performance metrics from portfolio value history.
    /// </summary>
    /// <param name="portfolioValues">Chronological list of portfolio values.</param>
    /// <param name="initialCapital">The starting capital.</param>
    /// <param name="totalDays">Total duration of the backtest in days.</param>
    /// <param name="numberOfBuys">Number of buy trades executed (proxy for trade pairs).</param>
    /// <returns>A PerformanceMetrics object.</returns>
    public static PerformanceMetrics CalculatePerformanceMetrics(List<decimal> portfolioValues, decimal initialCapital, double totalDays, int numberOfBuys)
    {
        if (portfolioValues == null || !portfolioValues.Any() || initialCapital <= 0)
        {
            return new PerformanceMetrics { InitialCapital = initialCapital, FinalPortfolioValue = initialCapital }; // Return defaults
        }

        decimal finalValue = portfolioValues.Last();
        double totalReturnPercent = (double)((finalValue / initialCapital) - 1) * 100.0;

        // Annualized Return (Compound Annual Growth Rate - CAGR)
        double years = Math.Max(1.0, totalDays) / 365.25; // Avoid division by zero, ensure at least 1 day
        double annualizedReturnPercent = 0;
        if (years > 0 && initialCapital > 0) // Check initialCapital > 0
        {
            // Handle potential negative final value if shorting were allowed etc.
            // For simple long-only, portfolio value should be >= 0
             double finalToInitialRatio = (double)Math.Max(0, finalValue) / (double)initialCapital;
            annualizedReturnPercent = (Math.Pow(finalToInitialRatio, 1.0 / years) - 1.0) * 100.0;
        }


        // Daily Returns for Sharpe Ratio and Drawdown
        var dailyReturns = new List<double>();
        for (int i = 1; i < portfolioValues.Count; i++)
        {
            if (portfolioValues[i - 1] != 0) // Avoid division by zero
            {
                dailyReturns.Add((double)(portfolioValues[i] / portfolioValues[i - 1]) - 1.0);
            }
            else
            {
                dailyReturns.Add(0.0); // Or handle as appropriate if portfolio can go to zero
            }
        }

        // Sharpe Ratio (Annualized, assuming Risk-Free Rate = 0)
        double sharpeRatio = 0;
        if (dailyReturns.Any())
        {
            double avgDailyReturn = dailyReturns.Average();
            double stdDevDailyReturn = CalculateStandardDeviation(dailyReturns);

            if (stdDevDailyReturn != 0)
            {
                // Assuming 252 trading days per year
                sharpeRatio = (avgDailyReturn / stdDevDailyReturn) * Math.Sqrt(252);
            }
            // If stdDev is 0, returns were constant, Sharpe is technically infinite or undefined. 0 is a safe default.
        }

        // Max Drawdown
        double maxDrawdownPercent = 0;
        decimal peakValue = initialCapital;
        foreach (var value in portfolioValues)
        {
            peakValue = Math.Max(peakValue, value);
            if (peakValue > 0) // Avoid division by zero if peak is 0 (shouldn't happen with positive initial capital)
            {
                decimal drawdown = (value - peakValue) / peakValue;
                maxDrawdownPercent = Math.Min(maxDrawdownPercent, (double)drawdown);
            }
        }
         maxDrawdownPercent *= 100.0; // Convert to percentage


        return new PerformanceMetrics
        {
            InitialCapital = initialCapital,
            FinalPortfolioValue = finalValue,
            TotalReturnPercent = totalReturnPercent,
            AnnualizedReturnPercent = annualizedReturnPercent,
            SharpeRatio = sharpeRatio,
            MaxDrawdownPercent = maxDrawdownPercent,
            NumberOfTradePairs = numberOfBuys // Simple approximation
        };
    }


    /// <summary>
    /// Calculates the standard deviation of a sample.
    /// </summary>
    private static double CalculateStandardDeviation(IEnumerable<double> values)
    {
        if (values == null || !values.Any()) return 0;

        double avg = values.Average();
        double sumOfSquares = values.Sum(val => Math.Pow(val - avg, 2));

        // Use population standard deviation (N) if treating as entire population (e.g., all returns in period)
        // Or sample standard deviation (N-1) if treating as sample
        // For financial returns, population (N) is often acceptable for the period analyzed.
        int count = values.Count();
        return count > 0 ? Math.Sqrt(sumOfSquares / count) : 0;
        // return count > 1 ? Math.Sqrt(sumOfSquares / (count - 1)) : 0; // Sample StDev
    }
}
