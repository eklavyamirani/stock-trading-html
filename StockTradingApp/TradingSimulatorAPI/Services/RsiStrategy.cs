using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Utils;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Services;

public class RsiStrategy : IStrategy
{
    public string Name => "rsi_basic";

    public StrategyInfo Info => new StrategyInfo
    {
        Name = Name,
        DisplayName = "Relative Strength Index (RSI) Basic",
        Description = "Buys when RSI crosses above the oversold threshold. Sells when RSI crosses below the overbought threshold.",
        Parameters = new Dictionary<string, ParameterInfo>
        {
            { "rsiWindow", new ParameterInfo { Type = "integer", Description = "Window size for RSI calculation.", DefaultValue = 14 } },
            { "oversoldThreshold", new ParameterInfo { Type = "number", Description = "RSI level below which is considered oversold.", DefaultValue = 30.0 } },
            { "overboughtThreshold", new ParameterInfo { Type = "number", Description = "RSI level above which is considered overbought.", DefaultValue = 70.0 } }
        }
    };

     public List<int> GenerateSignals(List<HistoricalDataPoint> data, Dictionary<string, object>? parameters)
    {
        // --- Parameter Handling & Validation ---
        int rsiWindow = GetIntParameter(parameters, "rsiWindow", 14);
        double oversoldThreshold = GetDoubleParameter(parameters, "oversoldThreshold", 30.0);
        double overboughtThreshold = GetDoubleParameter(parameters, "overboughtThreshold", 70.0);

        if (rsiWindow <= 1)
        {
            throw new ArgumentException("RSI window must be greater than 1.");
        }
         if (oversoldThreshold >= overboughtThreshold)
        {
            throw new ArgumentException("Oversold threshold must be less than overbought threshold.");
        }
        if (data == null || data.Count <= rsiWindow) // Need enough data for RSI calculation + 1 previous day
        {
            return Enumerable.Repeat(0, data?.Count ?? 0).ToList();
        }


        // --- Calculations ---
        var closePrices = data.Select(d => d.Price).ToList();
        var rsiValues = CalculationUtils.CalculateRSI(closePrices, rsiWindow);

        var signals = new List<int>(data.Count);

         // Initialize signals for the period before RSI is calculated
        for (int i = 0; i <= rsiWindow; i++) // RSI needs `window` periods of changes, available at index `window`
        {
            signals.Add(0);
        }

        // --- Signal Generation Logic ---
         // Start from index rsiWindow + 1 because we need rsiValues[i] and rsiValues[i-1]
        for (int i = rsiWindow + 1; i < data.Count; i++)
        {
            // Ensure RSI values are available for current and previous period
            if (rsiValues[i] == null || rsiValues[i-1] == null)
            {
                signals.Add(0); // Hold if RSI isn't calculated
                continue;
            }

            double currentRsi = rsiValues[i].Value;
            double previousRsi = rsiValues[i-1].Value;

            // Buy Signal: RSI crosses ABOVE the oversold threshold
            if (previousRsi <= oversoldThreshold && currentRsi > oversoldThreshold)
            {
                signals.Add(1); // Buy
            }
            // Sell Signal: RSI crosses BELOW the overbought threshold
            else if (previousRsi >= overboughtThreshold && currentRsi < overboughtThreshold)
            {
                signals.Add(-1); // Sell
            }
            else
            {
                signals.Add(0); // Hold
            }
        }

        return signals;
    }

     // Helper to safely get integer parameters
    private int GetIntParameter(Dictionary<string, object>? parameters, string key, int defaultValue)
    {
        if (parameters != null && parameters.TryGetValue(key, out object? value))
        {
            try { return Convert.ToInt32(value); }
            catch { /* Log warning */ Console.WriteLine($"Warning: Could not convert parameter '{key}' value '{value}' to int. Using default {defaultValue}."); return defaultValue; }
        }
        return defaultValue;
    }

    // Helper to safely get double parameters
    private double GetDoubleParameter(Dictionary<string, object>? parameters, string key, double defaultValue)
    {
       if (parameters != null && parameters.TryGetValue(key, out object? value))
        {
             try { return Convert.ToDouble(value); }
             catch { /* Log warning */ Console.WriteLine($"Warning: Could not convert parameter '{key}' value '{value}' to double. Using default {defaultValue}."); return defaultValue; }
        }
        return defaultValue;
    }
}
