using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Utils; // Assuming CalculationUtils is here
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Services;

public class SmaCrossoverStrategy : IStrategy
{
    public string Name => "sma_crossover";

    public StrategyInfo Info => new StrategyInfo
    {
        Name = Name,
        DisplayName = "Simple Moving Average (SMA) Crossover",
        Description = "Buys when a short-term SMA crosses above a long-term SMA. Sells when it crosses below.",
        Parameters = new Dictionary<string, ParameterInfo>
        {
            { "shortWindow", new ParameterInfo { Type = "integer", Description = "Window size for the short SMA.", DefaultValue = 50 } },
            { "longWindow", new ParameterInfo { Type = "integer", Description = "Window size for the long SMA.", DefaultValue = 200 } }
        }
    };

    public List<int> GenerateSignals(List<HistoricalDataPoint> data, Dictionary<string, object>? parameters)
    {
        // --- Parameter Handling & Validation ---
        int shortWindow = GetIntParameter(parameters, "shortWindow", 50);
        int longWindow = GetIntParameter(parameters, "longWindow", 200);

        if (shortWindow <= 0 || longWindow <= 0)
        {
            throw new ArgumentException("SMA window sizes must be positive.");
        }
        if (shortWindow >= longWindow)
        {
            throw new ArgumentException("Short window must be smaller than long window.");
        }
        if (data == null || data.Count < longWindow) // Need enough data for the longest window
        {
            // Not enough data to calculate, return all hold signals or throw
            return Enumerable.Repeat(0, data?.Count ?? 0).ToList();
            // throw new ArgumentException("Not enough historical data points for the specified long window.");
        }

        // --- Calculations ---
        var closePrices = data.Select(d => d.Price).ToList(); // Use Close or AdjClose
        var shortSma = CalculationUtils.CalculateSMA(closePrices, shortWindow);
        var longSma = CalculationUtils.CalculateSMA(closePrices, longWindow);

        var signals = new List<int>(data.Count);

        // Initialize signals for the period before the long MA is calculated
        for (int i = 0; i < longWindow -1; i++)
        {
            signals.Add(0); // Hold signal initially
        }

        // --- Signal Generation Logic ---
        for (int i = longWindow - 1; i < data.Count; i++)
        {
             // Check if values exist (should, given initial check, but good practice)
             if (shortSma[i] == null || longSma[i] == null || shortSma[i-1] == null || longSma[i-1] == null)
             {
                  signals.Add(0); // Hold if MAs aren't calculated yet
                  continue;
             }

            // Buy Signal: Short MA crosses ABOVE Long MA
            // Check if short was below or equal previously AND is above now
            if (shortSma[i-1] <= longSma[i-1] && shortSma[i] > longSma[i])
            {
                signals.Add(1); // Buy
            }
            // Sell Signal: Short MA crosses BELOW Long MA
            // Check if short was above or equal previously AND is below now
            else if (shortSma[i-1] >= longSma[i-1] && shortSma[i] < longSma[i])
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

     // Helper to safely get integer parameters with default values
    private int GetIntParameter(Dictionary<string, object>? parameters, string key, int defaultValue)
    {
        if (parameters != null && parameters.TryGetValue(key, out object? value))
        {
            try
            {
                // Handles values coming as long (from JSON deserialization) or int
                 return Convert.ToInt32(value);
            }
            catch (Exception ex)
            {
                 // Log warning about conversion issue?
                 Console.WriteLine($"Warning: Could not convert parameter '{key}' value '{value}' to int. Using default {defaultValue}. Error: {ex.Message}");
                 return defaultValue;
            }
        }
        return defaultValue;
    }
}
