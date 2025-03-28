using System.ComponentModel.DataAnnotations;

namespace TradingSimulatorAPI.Models;

public class BacktestRequest
{
    [Required(ErrorMessage = "Ticker symbol is required.")]
    [RegularExpression(@"^[A-Z\^.-]{1,10}$", ErrorMessage = "Invalid ticker format.")] // Basic validation
    public string Ticker { get; set; } = string.Empty;

    [Required(ErrorMessage = "Start date is required.")]
    [DataType(DataType.Date)]
    public DateTime StartDate { get; set; }

    [Required(ErrorMessage = "End date is required.")]
    [DataType(DataType.Date)]
    public DateTime EndDate { get; set; }

    [Required(ErrorMessage = "Strategy name is required.")]
    public string StrategyName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Initial capital is required.")]
    [Range(1.0, double.MaxValue, ErrorMessage = "Initial capital must be positive.")]
    public decimal InitialCapital { get; set; } = 100000;

    // Optional strategy-specific parameters (e.g., {"shortWindow": 50, "longWindow": 200})
    public Dictionary<string, object>? Parameters { get; set; }
}
