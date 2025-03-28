namespace TradingSimulatorAPI.Models;

public class PerformanceMetrics
{
    public decimal InitialCapital { get; set; }
    public decimal FinalPortfolioValue { get; set; }
    public double TotalReturnPercent { get; set; } // As percentage (e.g., 15.5 for 15.5%)
    public double AnnualizedReturnPercent { get; set; } // As percentage
    public double SharpeRatio { get; set; } // Annualized, assumes 0 risk-free rate
    public double MaxDrawdownPercent { get; set; } // As percentage (e.g., -10.2 for -10.2%)
    public int NumberOfTradePairs { get; set; } // Approx number of buy/sell cycles
}
