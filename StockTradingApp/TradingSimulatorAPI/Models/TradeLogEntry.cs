namespace TradingSimulatorAPI.Models;

public enum TradeAction { BUY, SELL }

public class TradeLogEntry
{
    public DateTime Date { get; set; }
    public TradeAction Action { get; set; }
    public decimal Price { get; set; }
    public decimal Shares { get; set; }
    public decimal? Cost { get; set; } // Total cost for BUY actions
    public decimal? Proceeds { get; set; } // Total proceeds for SELL actions
    public decimal? Commission { get; set; } // Optional: If commissions are added
}
