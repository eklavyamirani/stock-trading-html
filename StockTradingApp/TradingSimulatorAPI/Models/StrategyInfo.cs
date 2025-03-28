namespace TradingSimulatorAPI.Models;

public class StrategyInfo
{
    public string Name { get; set; } = string.Empty; // Internal identifier
    public string DisplayName { get; set; } = string.Empty; // User-friendly name
    public string Description { get; set; } = string.Empty;
    public Dictionary<string, ParameterInfo>? Parameters { get; set; } // Info about parameters
}

public class ParameterInfo
{
    public string Type { get; set; } = "number"; // e.g., "number", "integer", "string"
    public string Description { get; set; } = string.Empty;
    public object? DefaultValue { get; set; }
}
