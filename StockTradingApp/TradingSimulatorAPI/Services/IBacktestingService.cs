using TradingSimulatorAPI.Models;

namespace TradingSimulatorAPI.Services;

public interface IBacktestingService
{
    /// <summary>
    /// Runs a backtest simulation for a given strategy.
    /// </summary>
    /// <param name="ticker">Stock ticker.</param>
    /// <param name="startDate">Simulation start date.</param>
    /// <param name="endDate">Simulation end date.</param>
    /// <param name="strategyName">Name of the strategy to use.</param>
    /// <param name="initialCapital">Starting capital for the simulation.</param>
    /// <param name="strategyParameters">Parameters for the chosen strategy.</param>
    /// <returns>A BacktestResult object containing metrics, history, and logs, or null if critical errors occur (e.g., data fetch failure).</returns>
    Task<BacktestResult?> RunBacktestAsync(
        string ticker,
        DateTime startDate,
        DateTime endDate,
        string strategyName,
        decimal initialCapital,
        Dictionary<string, object>? strategyParameters);
}
