namespace TradingSimulatorAPI.Models;

public class BacktestResult
{
    public string StrategyName { get; set; } = string.Empty;
    public string Ticker { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public PerformanceMetrics? Metrics { get; set; }
    public List<ChartDataPoint> PortfolioValueHistory { get; set; } = new();
    public List<ChartDataPoint> BenchmarkValueHistory { get; set; } = new(); // Normalized benchmark price
    public List<TradeLogEntry> TradeLog { get; set; } = new();
    public string? ErrorMessage { get; set; } // To report errors during backtest execution
    // public List<SignalDataPoint>? SignalsData { get; set; } // Optional: Include if needed for detailed frontend charts
}

// Optional: If sending raw signals/indicator data
// public class SignalDataPoint : HistoricalDataPoint
// {
//     public int Signal { get; set; } // -1, 0, 1
//     public Dictionary<string, double?> Indicators { get; set; } = new(); // e.g., {"SMA50": 150.5, "RSI": 65.2}
// }
