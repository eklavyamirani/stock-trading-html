using TradingSimulatorAPI.Models;

namespace TradingSimulatorAPI.Services;

/// <summary>
/// Represents a trading strategy that can generate trading signals based on historical data.
/// </summary>
public interface IStrategy
{
    /// <summary>
    /// Gets the unique name identifier for the strategy.
    /// </summary>
    string Name { get; }

    /// <summary>
    /// Gets descriptive information about the strategy.
    /// </summary>
    StrategyInfo Info { get; }

    /// <summary>
    /// Generates trading signals for the given historical data.
    /// </summary>
    /// <param name="data">The historical stock data.</param>
    /// <param name="parameters">Optional dictionary of parameters to configure the strategy.</param>
    /// <returns>A list of integers representing signals (-1 for Sell, 0 for Hold, 1 for Buy) corresponding to each data point.</returns>
    /// <exception cref="ArgumentException">Thrown if required parameters are missing or invalid.</exception>
    List<int> GenerateSignals(List<HistoricalDataPoint> data, Dictionary<string, object>? parameters);
}
