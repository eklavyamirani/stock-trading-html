using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Utils;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TradingSimulatorAPI.Services;

public class BacktestingService : IBacktestingService
{
    private readonly IStockDataService _stockDataService;
    private readonly StrategyFactory _strategyFactory;
    private readonly ILogger<BacktestingService> _logger;

    public BacktestingService(
        IStockDataService stockDataService,
        StrategyFactory strategyFactory,
        ILogger<BacktestingService> logger)
    {
        _stockDataService = stockDataService;
        _strategyFactory = strategyFactory;
        _logger = logger;
    }

    public async Task<BacktestResult?> RunBacktestAsync(
        string ticker,
        DateTime startDate,
        DateTime endDate,
        string strategyName,
        decimal initialCapital,
        Dictionary<string, object>? strategyParameters)
    {
        _logger.LogInformation("Starting backtest for {Ticker}, Strategy: {Strategy}, Period: {StartDate} - {EndDate}", ticker, strategyName, startDate, endDate);

        var result = new BacktestResult
        {
            Ticker = ticker,
            StartDate = startDate,
            EndDate = endDate,
            StrategyName = strategyName
        };

        try
        {
            // 1. Fetch Historical Data
            var historicalData = await _stockDataService.GetHistoricalDataAsync(ticker, startDate, endDate);
            if (historicalData == null || !historicalData.Any())
            {
                _logger.LogWarning("No historical data found for {Ticker} between {StartDate} and {EndDate}.", ticker, startDate, endDate);
                result.ErrorMessage = "Failed to fetch historical data or no data available for the period.";
                return result; // Return result with error message
            }

            // Ensure data is sorted by date (should be handled by data service, but double-check)
             historicalData = historicalData.OrderBy(d => d.Date).ToList();


            // 2. Get Strategy and Generate Signals
            IStrategy strategy = _strategyFactory.GetStrategy(strategyName); // Throws ArgumentException if not found
            List<int> signals = strategy.GenerateSignals(historicalData, strategyParameters); // Can throw ArgumentException

            if (signals.Count != historicalData.Count)
            {
                 _logger.LogError("Signal count ({SignalCount}) does not match data count ({DataCount}) for strategy {Strategy}", signals.Count, historicalData.Count, strategyName);
                 result.ErrorMessage = "Internal error: Signal generation mismatch.";
                 return result;
            }


            // 3. Run Simulation
            decimal cash = initialCapital;
            decimal position = 0m; // Shares held
            var portfolioValueHistory = new List<ChartDataPoint>(historicalData.Count);
            var tradeLog = new List<TradeLogEntry>();

             _logger.LogDebug("Starting simulation loop with initial capital {InitialCapital}", initialCapital);

            for (int i = 0; i < historicalData.Count; i++)
            {
                var dayData = historicalData[i];
                var signal = signals[i];
                // Trade execution price - Using Close. Could use Open of next day, etc.
                decimal executionPrice = dayData.Price;

                // --- Portfolio Value Update (Start of Day) ---
                // Value is cash + value of shares held at current price
                decimal currentPortfolioValue = cash + (position * executionPrice);
                portfolioValueHistory.Add(new ChartDataPoint { Date = dayData.Date.ToString("o"), Value = currentPortfolioValue }); // ISO 8601 format


                // --- Trade Execution Logic ---
                // Simplified: Ignores commission, slippage. Executes at Close price on signal day.
                // Assumes buying/selling full position.

                if (signal == 1 && position == 0) // Buy Signal and currently flat
                {
                    if (cash > 0 && executionPrice > 0)
                    {
                        decimal sharesToBuy = Math.Floor(cash / executionPrice); // Buy whole shares
                        if (sharesToBuy > 0)
                        {
                            decimal cost = sharesToBuy * executionPrice;
                            position += sharesToBuy;
                            cash -= cost;
                            tradeLog.Add(new TradeLogEntry
                            {
                                Date = dayData.Date,
                                Action = TradeAction.BUY,
                                Price = executionPrice,
                                Shares = sharesToBuy,
                                Cost = cost
                            });
                            _logger.LogTrace("{Date}: BUY {Shares} @ {Price:F2}, Cost: {Cost:F2}, Cash: {Cash:F2}", dayData.Date.ToShortDateString(), sharesToBuy, executionPrice, cost, cash);
                        }
                    }
                }
                else if (signal == -1 && position > 0) // Sell Signal and currently long
                {
                     if (executionPrice > 0)
                     {
                        decimal proceeds = position * executionPrice;
                        decimal sharesSold = position;
                        cash += proceeds;
                        position = 0;
                        tradeLog.Add(new TradeLogEntry
                        {
                            Date = dayData.Date,
                            Action = TradeAction.SELL,
                            Price = executionPrice,
                            Shares = sharesSold,
                            Proceeds = proceeds
                        });
                        _logger.LogTrace("{Date}: SELL {Shares} @ {Price:F2}, Proceeds: {Proceeds:F2}, Cash: {Cash:F2}", dayData.Date.ToShortDateString(), sharesSold, executionPrice, proceeds, cash);
                     }
                }
                 // No action on signal 0 or if conditions aren't met (e.g., trying to sell when flat)

                 // Optional: Update portfolio value again *after* trade for end-of-day value
                 // decimal endOfDayPortfolioValue = cash + (position * executionPrice);
                 // portfolioValueHistory[i] = new ChartDataPoint { Date = dayData.Date.ToString("o"), Value = endOfDayPortfolioValue };
            }

            _logger.LogDebug("Simulation loop finished. Final Cash: {FinalCash}, Final Position: {FinalPosition}", cash, position);


            // 4. Calculate Metrics
             if (portfolioValueHistory.Any())
             {
                result.Metrics = CalculationUtils.CalculatePerformanceMetrics(
                    portfolioValueHistory.Select(p => p.Value).ToList(),
                    initialCapital,
                    (endDate - startDate).TotalDays,
                    tradeLog.Count(t => t.Action == TradeAction.BUY) // Number of buy trades as proxy for pairs
                );
                _logger.LogInformation("Calculated performance metrics. Final Value: {FinalValue}, Total Return: {TotalReturn}%",
                    result.Metrics?.FinalPortfolioValue, result.Metrics?.TotalReturnPercent);
            }
            else
            {
                 _logger.LogWarning("Portfolio history is empty, cannot calculate metrics.");
                 // Add minimal metrics if possible
                 result.Metrics = new PerformanceMetrics { InitialCapital = initialCapital, FinalPortfolioValue = initialCapital };
            }


            // 5. Prepare Benchmark Data (Normalized)
            var benchmarkHistory = historicalData.Select(d => new ChartDataPoint
            {
                Date = d.Date.ToString("o"),
                // Normalize benchmark (raw close price) relative to initial capital
                Value = historicalData[0].Price > 0 ? (d.Price / historicalData[0].Price) * initialCapital : initialCapital
            }).ToList();


            // 6. Populate Result Object
            result.PortfolioValueHistory = portfolioValueHistory;
            result.BenchmarkValueHistory = benchmarkHistory;
            result.TradeLog = tradeLog;
        }
        catch (ArgumentException ex) // Catch specific errors from strategy factory or generation
        {
             _logger.LogError(ex, "Argument error during backtest setup or signal generation for strategy {Strategy}", strategyName);
             result.ErrorMessage = $"Configuration error for strategy '{strategyName}': {ex.Message}";
        }
        catch (HttpRequestException ex) // Catch errors from data service
        {
            _logger.LogError(ex, "Data fetching error during backtest for {Ticker}", ticker);
            result.ErrorMessage = $"Failed to fetch data for {ticker}: {ex.Message}";
        }
        catch (Exception ex) // Catch all other unexpected errors
        {
            _logger.LogError(ex, "An unexpected error occurred during backtest for {Ticker}, Strategy: {Strategy}", ticker, strategyName);
            result.ErrorMessage = $"An unexpected internal error occurred: {ex.Message}";
        }

        _logger.LogInformation("Backtest finished for {Ticker}, Strategy: {Strategy}.", ticker, strategyName);
        return result; // Return result, potentially with ErrorMessage set
    }
}
