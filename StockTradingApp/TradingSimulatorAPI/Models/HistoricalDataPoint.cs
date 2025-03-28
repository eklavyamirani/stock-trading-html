namespace TradingSimulatorAPI.Models;

public class HistoricalDataPoint
{
    public DateTime Date { get; set; }
    public decimal Open { get; set; }
    public decimal High { get; set; }
    public decimal Low { get; set; }
    public decimal Close { get; set; }
    public decimal AdjClose { get; set; }
    public long Volume { get; set; }

    // Convenience property for calculations often based on Close or AdjClose
    public decimal Price => Close; // Or AdjClose, depending on preference/strategy needs
}
