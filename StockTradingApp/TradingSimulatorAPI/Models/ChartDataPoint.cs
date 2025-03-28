namespace TradingSimulatorAPI.Models;

// Structure expected by frontend charting libraries
public class ChartDataPoint
{
    // Use string for date for easy JS consumption, or long for timestamp
    public string Date { get; set; } = string.Empty; // ISO 8601 format recommended (YYYY-MM-DDTHH:mm:ssZ)
    // public long Timestamp { get; set; } // Alternative: Unix timestamp ms

    public decimal Value { get; set; }
}
