#!/bin/bash

echo "-----------------------------------------------------"
echo "--- Creating Full Stock Trading Simulator Project ---"
echo "-----------------------------------------------------"
echo "WARNING: This script embeds ALL source code and will overwrite existing files."
echo "WARNING: Replace placeholder API keys in appsettings.json with a secure method!"
echo "Requires: bash, dotnet SDK (6+), node, npx (or yarn)"
echo "-----------------------------------------------------"
read -p "Press Enter to continue, or Ctrl+C to abort..."

# --- Create Root Directory ---
ROOT_DIR="StockTradingApp"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR" || { echo "Failed to enter root directory $ROOT_DIR"; exit 1; }
echo "[INFO] Created root directory: $ROOT_DIR"

# =====================================================
#                  BACKEND (.NET Web API)
# =====================================================
BACKEND_DIR="TradingSimulatorAPI"
echo "[INFO] Setting up .NET backend in $BACKEND_DIR..."

# Use dotnet new to create the base project structure
# Using controller-based template for clarity with provided code examples
dotnet new webapi -o "$BACKEND_DIR" --no-openapi # Add --minimal if preferred
if [ $? -ne 0 ]; then echo "[ERROR] dotnet new webapi failed."; exit 1; fi

cd "$BACKEND_DIR" || { echo "Failed to enter backend directory $BACKEND_DIR"; exit 1; }
echo "[INFO] Base .NET project created."

# Remove default WeatherForecast controller and model if they exist
rm -f Controllers/WeatherForecastController.cs Models/WeatherForecast.cs

# Create additional directories
mkdir -p Models Services Utils
echo "[INFO] Created backend directories: Models, Services, Utils"

# --- Write appsettings.json ---
echo "[INFO] Writing appsettings.json..."
cat << 'EOF' > appsettings.json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "OpenAI": {
    "ApiKey": "YOUR_OPENAI_API_KEY_HERE", // <-- VERY IMPORTANT: Replace with User Secrets/Env Var/Key Vault
    "Model": "gpt-3.5-turbo"
  },
  "CorsSettings": {
     "AllowedOrigins": "http://localhost:3000" // Default React dev server port
   },
   "YahooFinanceApi": { // Optional: Configuration if library needs it
      "BaseUrl": "https://query1.finance.yahoo.com"
   }
}
EOF

# --- Write Program.cs ---
echo "[INFO] Writing Program.cs..."
cat << 'EOF' > Program.cs
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Services;
using Microsoft.Extensions.Options; // Required for IOptions

var builder = WebApplication.CreateBuilder(args);

// --- Add services to the container ---

// Configuration
var corsSettings = builder.Configuration.GetSection("CorsSettings");
var allowedOrigins = corsSettings["AllowedOrigins"]?.Split(',') ?? new string[] { "http://localhost:3000" }; // Default

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigin",
        policy =>
        {
            policy.WithOrigins(allowedOrigins) // Read from config
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        });
});


// Add Controllers
builder.Services.AddControllers();

// Register Application Services (Dependency Injection)
builder.Services.AddHttpClient(); // Needed for services making HTTP calls (like data fetcher, LLM)

// --- Data Service Registration ---
// Choose ONE data service implementation or add logic to select based on config
builder.Services.AddScoped<IStockDataService, YahooFinanceStockDataService>();
// Example using Alpha Vantage (requires separate setup and API key)
// builder.Services.AddScoped<IStockDataService, AlphaVantageStockDataService>();
// builder.Services.Configure<AlphaVantageSettings>(builder.Configuration.GetSection("AlphaVantage"));


// --- Strategy Registration ---
// Register the factory
builder.Services.AddScoped<StrategyFactory>();
// Register individual strategies that the factory can resolve
builder.Services.AddScoped<SmaCrossoverStrategy>(); // Register by concrete type
builder.Services.AddScoped<RsiStrategy>();         // Register by concrete type
// The StrategyFactory will use IServiceProvider to get these instances


// --- Backtesting Service ---
builder.Services.AddScoped<IBacktestingService, BacktestingService>();


// --- LLM Service Registration ---
builder.Services.AddScoped<ILLMService, OpenAILLMService>(); // Example for OpenAI
builder.Services.Configure<OpenAISettings>(builder.Configuration.GetSection("OpenAI"));
// Example for Anthropic (requires separate setup and API key)
// builder.Services.AddScoped<ILLMService, AnthropicLLMService>();
// builder.Services.Configure<AnthropicSettings>(builder.Configuration.GetSection("Anthropic"));


// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer(); // Generates descriptions for API endpoints
builder.Services.AddSwaggerGen(); // Generates the Swagger JSON document and UI


var app = builder.Build();

// --- Configure the HTTP request pipeline ---
if (app.Environment.IsDevelopment())
{
    app.UseSwagger(); // Enable middleware to serve generated Swagger as JSON endpoint.
    app.UseSwaggerUI(); // Enable middleware to serve swagger-ui (HTML, JS, CSS, etc.)
    app.UseDeveloperExceptionPage(); // More detailed errors in dev
}
else
{
    // Optional: Add production error handling (e.g., logging, custom error page)
    // app.UseExceptionHandler("/Error");
    app.UseHsts(); // Enforce HTTPS in production
}

app.UseHttpsRedirection(); // Redirect HTTP requests to HTTPS

app.UseRouting(); // Add UseRouting before UseCors and UseAuthorization

app.UseCors("AllowSpecificOrigin"); // Apply the CORS policy IMPORTANT: Must be between UseRouting and UseEndpoints

app.UseAuthorization(); // Should generally come after UseCors

app.MapControllers(); // Maps attribute-routed controllers

app.Run();


// --- Configuration Classes (Examples) ---
public class OpenAISettings
{
    public string ApiKey { get; set; } = string.Empty;
    public string Model { get; set; } = "gpt-3.5-turbo";
}

// Example for Alpha Vantage (if used)
// public class AlphaVantageSettings
// {
//     public string ApiKey { get; set; } = string.Empty;
// }

// Example for Anthropic (if used)
// public class AnthropicSettings
// {
//     public string ApiKey { get; set; } = string.Empty;
//     public string Model { get; set; } = "claude-3-opus-20240229";
// }
EOF

# --- Write Models ---
echo "[INFO] Writing Model files..."
cat << 'EOF' > Models/BacktestRequest.cs
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
EOF

cat << 'EOF' > Models/BacktestResult.cs
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
EOF

cat << 'EOF' > Models/PerformanceMetrics.cs
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
EOF

cat << 'EOF' > Models/HistoricalDataPoint.cs
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
EOF

cat << 'EOF' > Models/TradeLogEntry.cs
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
EOF

cat << 'EOF' > Models/LLMRequest.cs
namespace TradingSimulatorAPI.Models;

public class LLMRequest
{
    public string Question { get; set; } = string.Empty;
    public string? Context { get; set; } // Optional context (e.g., strategy results)
    public List<ChatMessage>? ConversationHistory { get; set; } // Optional for maintaining state
}

public class ChatMessage
{
    public string Role { get; set; } = string.Empty; // "user" or "assistant" or "system"
    public string Content { get; set; } = string.Empty;
}
EOF

cat << 'EOF' > Models/LLMResponse.cs
namespace TradingSimulatorAPI.Models;

public class LLMResponse
{
    public string Answer { get; set; } = string.Empty;
    public List<ChatMessage>? UpdatedConversationHistory { get; set; } // Optional: Return updated history
    public string? Error { get; set; } // In case LLM call fails
}
EOF

cat << 'EOF' > Models/StrategyInfo.cs
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
EOF

cat << 'EOF' > Models/ChartDataPoint.cs
namespace TradingSimulatorAPI.Models;

// Structure expected by frontend charting libraries
public class ChartDataPoint
{
    // Use string for date for easy JS consumption, or long for timestamp
    public string Date { get; set; } = string.Empty; // ISO 8601 format recommended (YYYY-MM-DDTHH:mm:ssZ)
    // public long Timestamp { get; set; } // Alternative: Unix timestamp ms

    public decimal Value { get; set; }
}
EOF


# --- Write Services ---
echo "[INFO] Writing Service files..."

# --- Interfaces ---
cat << 'EOF' > Services/IStockDataService.cs
using TradingSimulatorAPI.Models;

namespace TradingSimulatorAPI.Services;

public interface IStockDataService
{
    /// <summary>
    /// Fetches historical stock data for a given ticker and date range.
    /// </summary>
    /// <param name="ticker">The stock ticker symbol.</param>
    /// <param name="startDate">Start date (inclusive).</param>
    /// <param name="endDate">End date (inclusive).</param>
    /// <returns>A list of historical data points, or null if fetching fails or no data found.</returns>
    /// <exception cref="HttpRequestException">Thrown if the underlying HTTP request fails.</exception>
    /// <exception cref="Exception">Thrown for other unexpected errors during data processing.</exception>
    Task<List<HistoricalDataPoint>?> GetHistoricalDataAsync(string ticker, DateTime startDate, DateTime endDate);
}
EOF

cat << 'EOF' > Services/IStrategy.cs
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
EOF

cat << 'EOF' > Services/IBacktestingService.cs
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
EOF

cat << 'EOF' > Services/ILLMService.cs
using TradingSimulatorAPI.Models;

namespace TradingSimulatorAPI.Services;

public interface ILLMService
{
    /// <summary>
    /// Sends a question (potentially with context and history) to the configured LLM.
    /// </summary>
    /// <param name="request">The LLM request object.</param>
    /// <returns>An LLMResponse containing the answer or an error message.</returns>
    Task<LLMResponse> AskAsync(LLMRequest request);
}
EOF


# --- Implementations ---
cat << 'EOF' > Services/YahooFinanceStockDataService.cs
using TradingSimulatorAPI.Models;
using YahooFinanceApi; // Assuming usage of a library like this
using Microsoft.Extensions.Logging;

namespace TradingSimulatorAPI.Services;

// WARNING: Reliance on unofficial APIs like Yahoo Finance can be unstable.
// Consider paid, reliable data providers for serious applications.
public class YahooFinanceStockDataService : IStockDataService
{
    private readonly ILogger<YahooFinanceStockDataService> _logger;

    public YahooFinanceStockDataService(ILogger<YahooFinanceStockDataService> logger)
    {
        _logger = logger;
        // Configure YahooFinanceApi if necessary (e.g., setting up caching)
        // Yahoo.SetCache(TimeSpan.FromMinutes(30));
    }

    public async Task<List<HistoricalDataPoint>?> GetHistoricalDataAsync(string ticker, DateTime startDate, DateTime endDate)
    {
        _logger.LogInformation("Fetching historical data for {Ticker} from {StartDate} to {EndDate}", ticker, startDate, endDate);

        // Ensure end date is inclusive for YahooFinanceApi if needed (it's often exclusive)
        // Adjusting might be needed based on the specific library's behavior.
        // Sometimes adding a day helps: endDate.AddDays(1);

        try
        {
            // Example using a hypothetical YahooFinanceApi library structure
            var history = await Yahoo.GetHistoricalAsync(ticker, startDate, endDate, Period.Daily);

            if (history == null || !history.Any())
            {
                _logger.LogWarning("No historical data found for {Ticker} in the specified range.", ticker);
                return null; // Return null or empty list based on desired API contract
            }

            // Map the library's Candle type to our HistoricalDataPoint model
            var dataPoints = history
                .OrderBy(c => c.DateTime) // Ensure data is sorted chronologically
                .Select(c => new HistoricalDataPoint
                {
                    Date = c.DateTime.Date, // Use Date part only if Time is irrelevant
                    Open = c.Open,
                    High = c.High,
                    Low = c.Low,
                    Close = c.Close,
                    AdjClose = c.AdjustedClose, // Ensure correct mapping
                    Volume = c.Volume
                })
                .ToList();

            _logger.LogInformation("Successfully fetched {Count} data points for {Ticker}", dataPoints.Count, ticker);
            return dataPoints;
        }
        // Catch specific exceptions from the finance library if possible
        // catch (YahooFinanceException ex) { ... }
        catch (HttpRequestException ex)
        {
             _logger.LogError(ex, "HTTP request failed while fetching data for {Ticker}.", ticker);
             throw; // Re-throw or handle as appropriate
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unexpected error occurred while fetching or processing data for {Ticker}.", ticker);
            // Depending on requirements, you might return null, empty list, or re-throw
            return null; // Indicate failure
            // throw; // If the caller should handle all exceptions
        }
    }
}
EOF

cat << 'EOF' > Services/StrategyFactory.cs
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Services;

/// <summary>
/// Provides instances of registered trading strategies.
/// </summary>
public class StrategyFactory
{
    private readonly IServiceProvider _serviceProvider;
    private readonly Dictionary<string, Type> _strategyRegistry = new();
    private readonly List<StrategyInfo> _strategyInfos = new();

    // Use constructor injection to get access to the DI container
    public StrategyFactory(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
        RegisterStrategies();
    }

    private void RegisterStrategies()
    {
        // Manually register strategies or use reflection (more complex)
        // For manual registration, ensure the concrete strategy classes are registered in Program.cs
        RegisterStrategy<SmaCrossoverStrategy>();
        RegisterStrategy<RsiStrategy>();
        // Add more strategies here
    }

    private void RegisterStrategy<TStrategy>() where TStrategy : IStrategy
    {
         // We need an instance to get the Name and Info, resolved via DI
         // Use GetRequiredService to ensure the strategy is registered in DI container
         try
         {
             using var scope = _serviceProvider.CreateScope(); // Resolve within a scope
             var strategyInstance = scope.ServiceProvider.GetRequiredService<TStrategy>();
             var strategyName = strategyInstance.Name;

             if (_strategyRegistry.ContainsKey(strategyName))
             {
                 // Log warning or throw exception if duplicate name found
                 Console.WriteLine($"Warning: Duplicate strategy name '{strategyName}' detected during registration.");
                 return;
             }
            _strategyRegistry.Add(strategyName, typeof(TStrategy));
            _strategyInfos.Add(strategyInstance.Info); // Store info for listing later

         }
         catch (Exception ex)
         {
              Console.WriteLine($"Error registering strategy {typeof(TStrategy).Name}: {ex.Message}");
              // Decide how to handle registration errors (log, throw, etc.)
         }

    }


    /// <summary>
    /// Gets an instance of the strategy with the specified name.
    /// </summary>
    /// <param name="name">The unique name identifier of the strategy.</param>
    /// <returns>An instance of IStrategy.</returns>
    /// <exception cref="ArgumentException">Thrown if the strategy name is not found.</exception>
    public IStrategy GetStrategy(string name)
    {
        if (_strategyRegistry.TryGetValue(name, out Type? strategyType))
        {
            // Resolve the strategy instance using the DI container
            // This ensures any dependencies the strategy has are also injected
            try
            {
                 // Use GetRequiredService as we expect it to be registered if it's in the registry
                 // Resolve within a scope if the strategy has scoped dependencies
                 // Or directly if it's transient or singleton and has no scoped dependencies
                 // return (IStrategy)_serviceProvider.GetRequiredService(strategyType);

                 // Safer approach: Resolve within a temporary scope if unsure about dependency lifetimes
                  using var scope = _serviceProvider.CreateScope();
                  return (IStrategy)scope.ServiceProvider.GetRequiredService(strategyType);
            }
            catch (Exception ex)
            {
                 Console.WriteLine($"Error resolving strategy '{name}' from DI container: {ex.Message}");
                 throw new InvalidOperationException($"Could not resolve strategy '{name}'. Ensure it and its dependencies are registered correctly.", ex);
            }

        }
        throw new ArgumentException($"Strategy with name '{name}' not found.", nameof(name));
    }

    /// <summary>
    /// Gets information about all registered strategies.
    /// </summary>
    /// <returns>A list of StrategyInfo objects.</returns>
    public IEnumerable<StrategyInfo> GetAllStrategyInfos()
    {
        return _strategyInfos.OrderBy(info => info.DisplayName);
    }
}
EOF

cat << 'EOF' > Services/SmaCrossoverStrategy.cs
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Utils; // Assuming CalculationUtils is here
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Services;

public class SmaCrossoverStrategy : IStrategy
{
    public string Name => "sma_crossover";

    public StrategyInfo Info => new StrategyInfo
    {
        Name = Name,
        DisplayName = "Simple Moving Average (SMA) Crossover",
        Description = "Buys when a short-term SMA crosses above a long-term SMA. Sells when it crosses below.",
        Parameters = new Dictionary<string, ParameterInfo>
        {
            { "shortWindow", new ParameterInfo { Type = "integer", Description = "Window size for the short SMA.", DefaultValue = 50 } },
            { "longWindow", new ParameterInfo { Type = "integer", Description = "Window size for the long SMA.", DefaultValue = 200 } }
        }
    };

    public List<int> GenerateSignals(List<HistoricalDataPoint> data, Dictionary<string, object>? parameters)
    {
        // --- Parameter Handling & Validation ---
        int shortWindow = GetIntParameter(parameters, "shortWindow", 50);
        int longWindow = GetIntParameter(parameters, "longWindow", 200);

        if (shortWindow <= 0 || longWindow <= 0)
        {
            throw new ArgumentException("SMA window sizes must be positive.");
        }
        if (shortWindow >= longWindow)
        {
            throw new ArgumentException("Short window must be smaller than long window.");
        }
        if (data == null || data.Count < longWindow) // Need enough data for the longest window
        {
            // Not enough data to calculate, return all hold signals or throw
            return Enumerable.Repeat(0, data?.Count ?? 0).ToList();
            // throw new ArgumentException("Not enough historical data points for the specified long window.");
        }

        // --- Calculations ---
        var closePrices = data.Select(d => d.Price).ToList(); // Use Close or AdjClose
        var shortSma = CalculationUtils.CalculateSMA(closePrices, shortWindow);
        var longSma = CalculationUtils.CalculateSMA(closePrices, longWindow);

        var signals = new List<int>(data.Count);

        // Initialize signals for the period before the long MA is calculated
        for (int i = 0; i < longWindow -1; i++)
        {
            signals.Add(0); // Hold signal initially
        }

        // --- Signal Generation Logic ---
        for (int i = longWindow - 1; i < data.Count; i++)
        {
             // Check if values exist (should, given initial check, but good practice)
             if (shortSma[i] == null || longSma[i] == null || shortSma[i-1] == null || longSma[i-1] == null)
             {
                  signals.Add(0); // Hold if MAs aren't calculated yet
                  continue;
             }

            // Buy Signal: Short MA crosses ABOVE Long MA
            // Check if short was below or equal previously AND is above now
            if (shortSma[i-1] <= longSma[i-1] && shortSma[i] > longSma[i])
            {
                signals.Add(1); // Buy
            }
            // Sell Signal: Short MA crosses BELOW Long MA
            // Check if short was above or equal previously AND is below now
            else if (shortSma[i-1] >= longSma[i-1] && shortSma[i] < longSma[i])
            {
                signals.Add(-1); // Sell
            }
            else
            {
                signals.Add(0); // Hold
            }
        }

        return signals;
    }

     // Helper to safely get integer parameters with default values
    private int GetIntParameter(Dictionary<string, object>? parameters, string key, int defaultValue)
    {
        if (parameters != null && parameters.TryGetValue(key, out object? value))
        {
            try
            {
                // Handles values coming as long (from JSON deserialization) or int
                 return Convert.ToInt32(value);
            }
            catch (Exception ex)
            {
                 // Log warning about conversion issue?
                 Console.WriteLine($"Warning: Could not convert parameter '{key}' value '{value}' to int. Using default {defaultValue}. Error: {ex.Message}");
                 return defaultValue;
            }
        }
        return defaultValue;
    }
}
EOF

cat << 'EOF' > Services/RsiStrategy.cs
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Utils;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Services;

public class RsiStrategy : IStrategy
{
    public string Name => "rsi_basic";

    public StrategyInfo Info => new StrategyInfo
    {
        Name = Name,
        DisplayName = "Relative Strength Index (RSI) Basic",
        Description = "Buys when RSI crosses above the oversold threshold. Sells when RSI crosses below the overbought threshold.",
        Parameters = new Dictionary<string, ParameterInfo>
        {
            { "rsiWindow", new ParameterInfo { Type = "integer", Description = "Window size for RSI calculation.", DefaultValue = 14 } },
            { "oversoldThreshold", new ParameterInfo { Type = "number", Description = "RSI level below which is considered oversold.", DefaultValue = 30.0 } },
            { "overboughtThreshold", new ParameterInfo { Type = "number", Description = "RSI level above which is considered overbought.", DefaultValue = 70.0 } }
        }
    };

     public List<int> GenerateSignals(List<HistoricalDataPoint> data, Dictionary<string, object>? parameters)
    {
        // --- Parameter Handling & Validation ---
        int rsiWindow = GetIntParameter(parameters, "rsiWindow", 14);
        double oversoldThreshold = GetDoubleParameter(parameters, "oversoldThreshold", 30.0);
        double overboughtThreshold = GetDoubleParameter(parameters, "overboughtThreshold", 70.0);

        if (rsiWindow <= 1)
        {
            throw new ArgumentException("RSI window must be greater than 1.");
        }
         if (oversoldThreshold >= overboughtThreshold)
        {
            throw new ArgumentException("Oversold threshold must be less than overbought threshold.");
        }
        if (data == null || data.Count <= rsiWindow) // Need enough data for RSI calculation + 1 previous day
        {
            return Enumerable.Repeat(0, data?.Count ?? 0).ToList();
        }


        // --- Calculations ---
        var closePrices = data.Select(d => d.Price).ToList();
        var rsiValues = CalculationUtils.CalculateRSI(closePrices, rsiWindow);

        var signals = new List<int>(data.Count);

         // Initialize signals for the period before RSI is calculated
        for (int i = 0; i <= rsiWindow; i++) // RSI needs `window` periods of changes, available at index `window`
        {
            signals.Add(0);
        }

        // --- Signal Generation Logic ---
         // Start from index rsiWindow + 1 because we need rsiValues[i] and rsiValues[i-1]
        for (int i = rsiWindow + 1; i < data.Count; i++)
        {
            // Ensure RSI values are available for current and previous period
            if (rsiValues[i] == null || rsiValues[i-1] == null)
            {
                signals.Add(0); // Hold if RSI isn't calculated
                continue;
            }

            double currentRsi = rsiValues[i].Value;
            double previousRsi = rsiValues[i-1].Value;

            // Buy Signal: RSI crosses ABOVE the oversold threshold
            if (previousRsi <= oversoldThreshold && currentRsi > oversoldThreshold)
            {
                signals.Add(1); // Buy
            }
            // Sell Signal: RSI crosses BELOW the overbought threshold
            else if (previousRsi >= overboughtThreshold && currentRsi < overboughtThreshold)
            {
                signals.Add(-1); // Sell
            }
            else
            {
                signals.Add(0); // Hold
            }
        }

        return signals;
    }

     // Helper to safely get integer parameters
    private int GetIntParameter(Dictionary<string, object>? parameters, string key, int defaultValue)
    {
        if (parameters != null && parameters.TryGetValue(key, out object? value))
        {
            try { return Convert.ToInt32(value); }
            catch { /* Log warning */ Console.WriteLine($"Warning: Could not convert parameter '{key}' value '{value}' to int. Using default {defaultValue}."); return defaultValue; }
        }
        return defaultValue;
    }

    // Helper to safely get double parameters
    private double GetDoubleParameter(Dictionary<string, object>? parameters, string key, double defaultValue)
    {
       if (parameters != null && parameters.TryGetValue(key, out object? value))
        {
             try { return Convert.ToDouble(value); }
             catch { /* Log warning */ Console.WriteLine($"Warning: Could not convert parameter '{key}' value '{value}' to double. Using default {defaultValue}."); return defaultValue; }
        }
        return defaultValue;
    }
}
EOF

cat << 'EOF' > Services/BacktestingService.cs
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
EOF

cat << 'EOF' > Services/OpenAILLMService.cs
using Azure.AI.OpenAI; // Official Azure OpenAI SDK
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using TradingSimulatorAPI.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;


namespace TradingSimulatorAPI.Services;

public class OpenAILLMService : ILLMService
{
    private readonly OpenAISettings _settings;
    private readonly ILogger<OpenAILLMService> _logger;
    private readonly OpenAIClient _client;

    // System prompt defining the LLM's role
    private const string SystemPrompt = @"You are a helpful and knowledgeable financial trading assistant.
Your role is to explain stock trading strategies, interpret backtesting results,
and answer questions clearly and concisely for a user who is learning.
Avoid giving direct financial advice or making future predictions ('buy this stock', 'this will go up').
Focus on explaining concepts, pros/cons of strategies, and how to interpret metrics based ONLY on the provided context or general knowledge.
If context about a specific strategy or its results is provided, use it in your explanation.
Be objective and mention limitations where appropriate (e.g., backtests don't guarantee future results, simulations ignore costs like commissions/slippage/taxes).
Keep responses focused and reasonably concise. Do not invent data not provided in the context.
If asked for an opinion or prediction, politely decline and explain you provide informational guidance only.";


    public OpenAILLMService(IOptions<OpenAISettings> settings, ILogger<OpenAILLMService> logger)
    {
        _settings = settings.Value;
        _logger = logger;

        if (string.IsNullOrWhiteSpace(_settings.ApiKey))
        {
            _logger.LogError("OpenAI API key is missing. Please configure it in settings (using User Secrets or Environment Variables).");
            throw new InvalidOperationException("OpenAI API key is not configured.");
        }
         if (string.IsNullOrWhiteSpace(_settings.Model))
        {
             _logger.LogWarning("OpenAI Model is not configured, defaulting to gpt-3.5-turbo.");
             _settings.Model = "gpt-3.5-turbo"; // Set a default if missing
        }

        try
        {
            _client = new OpenAIClient(_settings.ApiKey);
             _logger.LogInformation("OpenAI client initialized successfully for model {Model}", _settings.Model);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize OpenAI client.");
            throw; // Re-throw exception to prevent service usage
        }
    }

    public async Task<LLMResponse> AskAsync(LLMRequest request)
    {
        _logger.LogInformation("Received LLM request. Question starts with: '{Start}'", request.Question.Substring(0, Math.Min(50, request.Question.Length)));

        var response = new LLMResponse();
        var messages = new List<ChatRequestMessage>();

        // 1. Add the System Prompt
        messages.Add(new ChatRequestSystemMessage(SystemPrompt));

        // 2. Add provided context as a system or user message (before the actual question)
        if (!string.IsNullOrWhiteSpace(request.Context))
        {
            // Option 1: Context as another system message
            // messages.Add(new ChatRequestSystemMessage($"Context for the user's question:\n{request.Context}"));

            // Option 2: Prepend context to the user's question (simpler for history)
            // Let's adjust the user question below
        }

        // 3. Add Conversation History (if provided)
        if (request.ConversationHistory != null && request.ConversationHistory.Any())
        {
            foreach (var message in request.ConversationHistory)
            {
                 if (message.Role.Equals("user", StringComparison.OrdinalIgnoreCase))
                 {
                      messages.Add(new ChatRequestUserMessage(message.Content));
                 }
                 else if (message.Role.Equals("assistant", StringComparison.OrdinalIgnoreCase))
                 {
                      messages.Add(new ChatRequestAssistantMessage(message.Content));
                 }
                 // Ignore system messages from history as we add our own canonical one
            }
             _logger.LogDebug("Added {HistoryCount} messages from provided history.", request.ConversationHistory.Count);
        }

        // 4. Add the Current User Question (potentially with context prepended)
        string userQuestionContent = string.IsNullOrWhiteSpace(request.Context)
            ? request.Question
            : $"Context:\n{request.Context}\n\nQuestion:\n{request.Question}";
        messages.Add(new ChatRequestUserMessage(userQuestionContent));


        // 5. Prepare OpenAI Request Options
        var chatCompletionsOptions = new ChatCompletionsOptions()
        {
            DeploymentName = _settings.Model, // Use DeploymentName for Azure OpenAI or model ID for non-Azure
            // Model = _settings.Model, // Use Model property if NOT using Azure OpenAI Service client
            Messages = messages,
            Temperature = 0.5f, // Adjust for creativity vs. factuality (0.0 to 1.0)
            MaxTokens = 1000, // Limit response length
            NucleusSamplingFactor = 0.95f, // Top-p sampling
            FrequencyPenalty = 0,
            PresencePenalty = 0,
        };

        try
        {
            _logger.LogDebug("Sending request to OpenAI model {Model} with {MessageCount} messages.", _settings.Model, messages.Count);
            Azure.Response<ChatCompletions> openAiResponse = await _client.GetChatCompletionsAsync(chatCompletionsOptions);

            if (openAiResponse?.Value?.Choices?.Count > 0)
            {
                var choice = openAiResponse.Value.Choices[0];
                response.Answer = choice.Message.Content.Trim();
                 _logger.LogInformation("Received successful response from OpenAI. Finish Reason: {FinishReason}", choice.FinishReason);

                // Update conversation history for the response
                 response.UpdatedConversationHistory = request.ConversationHistory ?? new List<ChatMessage>();
                 // Add the user question *as it was sent* (including context if prepended)
                 response.UpdatedConversationHistory.Add(new ChatMessage { Role = "user", Content = userQuestionContent });
                 response.UpdatedConversationHistory.Add(new ChatMessage { Role = "assistant", Content = response.Answer });

                 // Optional: Trim history if it gets too long
                 response.UpdatedConversationHistory = TrimHistory(response.UpdatedConversationHistory);

            }
            else
            {
                _logger.LogWarning("OpenAI response was empty or contained no choices.");
                response.Error = "LLM returned an empty response.";
            }
        }
        catch (RequestFailedException ex) // Catch specific Azure SDK exception
        {
            _logger.LogError(ex, "OpenAI API request failed. Status: {Status}, ErrorCode: {Code}, Message: {Message}", ex.Status, ex.ErrorCode, ex.Message);
            response.Error = $"LLM API request failed: {ex.Message} (Status: {ex.Status})";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unexpected error occurred while interacting with OpenAI.");
            response.Error = $"An unexpected error occurred: {ex.Message}";
        }

        return response;
    }

     // Simple history trimming (keep system + last N user/assistant pairs)
    private List<ChatMessage> TrimHistory(List<ChatMessage> history, int maxMessages = 10) // Keep last 5 pairs (10 messages) + context
    {
         if (history.Count > maxMessages)
         {
              _logger.LogDebug("Trimming conversation history from {InitialCount} to ~{MaxCount} messages.", history.Count, maxMessages);
              // Keep the last 'maxMessages' items
              return history.Skip(history.Count - maxMessages).ToList();
         }
         return history;
    }
}
EOF


# --- Write Utils ---
echo "[INFO] Writing Utils/CalculationUtils.cs..."
cat << 'EOF' > Utils/CalculationUtils.cs
using TradingSimulatorAPI.Models;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Utils;

public static class CalculationUtils
{
    /// <summary>
    /// Calculates Simple Moving Average (SMA).
    /// </summary>
    /// <param name="data">List of data points (usually close prices).</param>
    /// <param name="window">The period window size.</param>
    /// <returns>A list of nullable doubles representing the SMA. Null if SMA cannot be calculated for a point.</returns>
    public static List<double?> CalculateSMA(List<decimal> data, int window)
    {
        if (window <= 0 || data == null || data.Count < window)
        {
            return Enumerable.Repeat<double?>(null, data?.Count ?? 0).ToList();
        }

        var sma = new List<double?>(data.Count);
        // Fill initial points where SMA cannot be calculated with null
        for (int i = 0; i < window - 1; i++)
        {
            sma.Add(null);
        }

        decimal currentSum = data.Take(window).Sum();
        sma.Add((double)(currentSum / window));

        for (int i = window; i < data.Count; i++)
        {
            currentSum = currentSum - data[i - window] + data[i];
            sma.Add((double)(currentSum / window));
        }
        return sma;
    }

     /// <summary>
    /// Calculates Relative Strength Index (RSI) using Simple Moving Average for gains/losses.
    /// </summary>
    /// <param name="data">List of data points (usually close prices).</param>
    /// <param name="window">The period window size (typically 14).</param>
    /// <returns>A list of nullable doubles representing the RSI. Null if RSI cannot be calculated.</returns>
    public static List<double?> CalculateRSI(List<decimal> data, int window)
    {
        if (window <= 0 || data == null || data.Count <= window) // Need at least window+1 points for first RSI value
        {
            return Enumerable.Repeat<double?>(null, data?.Count ?? 0).ToList();
        }

        var rsi = new List<double?>(data.Count);
        var gains = new List<decimal>(data.Count);
        var losses = new List<decimal>(data.Count);

        // Calculate initial gains and losses
        gains.Add(0); // First element has no change
        losses.Add(0);
        for (int i = 1; i < data.Count; i++)
        {
            decimal change = data[i] - data[i - 1];
            gains.Add(Math.Max(0, change));
            losses.Add(Math.Max(0, -change));
        }

        // Calculate initial average gain and loss (using SMA for simplicity)
        decimal avgGain = gains.Skip(1).Take(window).Sum() / window;
        decimal avgLoss = losses.Skip(1).Take(window).Sum() / window;

        // Fill initial points where RSI cannot be calculated
        for (int i = 0; i <= window; i++) // RSI value is available at index `window` (needs `window` changes)
        {
            rsi.Add(null);
        }

        // Calculate first RSI value
         if (avgLoss == 0)
         {
             rsi[window] = 100.0; // Avoid division by zero; price consistently rose
         }
         else
         {
             decimal rs = avgGain / avgLoss;
             rsi[window] = (double)(100m - (100m / (1m + rs)));
         }


        // Calculate subsequent RSI values using Wilder's smoothing (approximation using SMA here for simplicity)
        // For a more accurate Wilder's smoothing:
        // AvgGain = ((PrevAvgGain * (window - 1)) + CurrentGain) / window
        // AvgLoss = ((PrevAvgLoss * (window - 1)) + CurrentLoss) / window
        for (int i = window + 1; i < data.Count; i++)
        {
            // Simple Moving Average approach for average gain/loss update:
             avgGain = gains.Skip(i - window).Take(window).Sum() / window;
             avgLoss = losses.Skip(i - window).Take(window).Sum() / window;

            if (avgLoss == 0)
            {
                rsi.Add(100.0); // Price consistently rose or stayed flat
            }
            else
            {
                decimal rs = avgGain / avgLoss;
                rsi.Add((double)(100m - (100m / (1m + rs))));
            }
        }
         // Pad the end if necessary (shouldn't be needed if loop goes to data.Count)
        // while (rsi.Count < data.Count) { rsi.Add(null); }

        return rsi;
    }


    /// <summary>
    /// Calculates performance metrics from portfolio value history.
    /// </summary>
    /// <param name="portfolioValues">Chronological list of portfolio values.</param>
    /// <param name="initialCapital">The starting capital.</param>
    /// <param name="totalDays">Total duration of the backtest in days.</param>
    /// <param name="numberOfBuys">Number of buy trades executed (proxy for trade pairs).</param>
    /// <returns>A PerformanceMetrics object.</returns>
    public static PerformanceMetrics CalculatePerformanceMetrics(List<decimal> portfolioValues, decimal initialCapital, double totalDays, int numberOfBuys)
    {
        if (portfolioValues == null || !portfolioValues.Any() || initialCapital <= 0)
        {
            return new PerformanceMetrics { InitialCapital = initialCapital, FinalPortfolioValue = initialCapital }; // Return defaults
        }

        decimal finalValue = portfolioValues.Last();
        double totalReturnPercent = (double)((finalValue / initialCapital) - 1) * 100.0;

        // Annualized Return (Compound Annual Growth Rate - CAGR)
        double years = Math.Max(1.0, totalDays) / 365.25; // Avoid division by zero, ensure at least 1 day
        double annualizedReturnPercent = 0;
        if (years > 0 && initialCapital > 0) // Check initialCapital > 0
        {
            // Handle potential negative final value if shorting were allowed etc.
            // For simple long-only, portfolio value should be >= 0
             double finalToInitialRatio = (double)Math.Max(0, finalValue) / (double)initialCapital;
            annualizedReturnPercent = (Math.Pow(finalToInitialRatio, 1.0 / years) - 1.0) * 100.0;
        }


        // Daily Returns for Sharpe Ratio and Drawdown
        var dailyReturns = new List<double>();
        for (int i = 1; i < portfolioValues.Count; i++)
        {
            if (portfolioValues[i - 1] != 0) // Avoid division by zero
            {
                dailyReturns.Add((double)(portfolioValues[i] / portfolioValues[i - 1]) - 1.0);
            }
            else
            {
                dailyReturns.Add(0.0); // Or handle as appropriate if portfolio can go to zero
            }
        }

        // Sharpe Ratio (Annualized, assuming Risk-Free Rate = 0)
        double sharpeRatio = 0;
        if (dailyReturns.Any())
        {
            double avgDailyReturn = dailyReturns.Average();
            double stdDevDailyReturn = CalculateStandardDeviation(dailyReturns);

            if (stdDevDailyReturn != 0)
            {
                // Assuming 252 trading days per year
                sharpeRatio = (avgDailyReturn / stdDevDailyReturn) * Math.Sqrt(252);
            }
            // If stdDev is 0, returns were constant, Sharpe is technically infinite or undefined. 0 is a safe default.
        }

        // Max Drawdown
        double maxDrawdownPercent = 0;
        decimal peakValue = initialCapital;
        foreach (var value in portfolioValues)
        {
            peakValue = Math.Max(peakValue, value);
            if (peakValue > 0) // Avoid division by zero if peak is 0 (shouldn't happen with positive initial capital)
            {
                decimal drawdown = (value - peakValue) / peakValue;
                maxDrawdownPercent = Math.Min(maxDrawdownPercent, (double)drawdown);
            }
        }
         maxDrawdownPercent *= 100.0; // Convert to percentage


        return new PerformanceMetrics
        {
            InitialCapital = initialCapital,
            FinalPortfolioValue = finalValue,
            TotalReturnPercent = totalReturnPercent,
            AnnualizedReturnPercent = annualizedReturnPercent,
            SharpeRatio = sharpeRatio,
            MaxDrawdownPercent = maxDrawdownPercent,
            NumberOfTradePairs = numberOfBuys // Simple approximation
        };
    }


    /// <summary>
    /// Calculates the standard deviation of a sample.
    /// </summary>
    private static double CalculateStandardDeviation(IEnumerable<double> values)
    {
        if (values == null || !values.Any()) return 0;

        double avg = values.Average();
        double sumOfSquares = values.Sum(val => Math.Pow(val - avg, 2));

        // Use population standard deviation (N) if treating as entire population (e.g., all returns in period)
        // Or sample standard deviation (N-1) if treating as sample
        // For financial returns, population (N) is often acceptable for the period analyzed.
        int count = values.Count();
        return count > 0 ? Math.Sqrt(sumOfSquares / count) : 0;
        // return count > 1 ? Math.Sqrt(sumOfSquares / (count - 1)) : 0; // Sample StDev
    }
}
EOF

# --- Write Controllers ---
echo "[INFO] Writing Controller files..."
mkdir -p Controllers
cat << 'EOF' > Controllers/BacktestController.cs
using Microsoft.AspNetCore.Mvc;
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Services;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace TradingSimulatorAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BacktestController : ControllerBase
{
    private readonly IBacktestingService _backtestingService;
    private readonly ILogger<BacktestController> _logger;

    public BacktestController(IBacktestingService backtestingService, ILogger<BacktestController> logger)
    {
        _backtestingService = backtestingService;
        _logger = logger;
    }

    /// <summary>
    /// Runs a trading strategy backtest simulation.
    /// </summary>
    /// <param name="request">Parameters for the backtest run.</param>
    /// <returns>The results of the backtest, including metrics and history.</returns>
    [HttpPost("run")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(BacktestResult))]
    [ProducesResponseType(StatusCodes.Status400BadRequest)] // For validation or argument errors
    [ProducesResponseType(StatusCodes.Status404NotFound)] // If data or strategy not found implicitly
    [ProducesResponseType(StatusCodes.Status500InternalServerError)] // For unexpected errors
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)] // If external services fail
    public async Task<ActionResult<BacktestResult>> RunBacktest([FromBody] BacktestRequest request)
    {
        // --- Input Validation ---
        if (!ModelState.IsValid)
        {
            // Return detailed validation errors (useful for debugging client-side)
            return BadRequest(ModelState);
        }
        if (request.StartDate >= request.EndDate)
        {
             return BadRequest("End date must be after start date.");
        }
         // Add more specific validation if needed (e.g., date range limits)

        try
        {
            _logger.LogInformation("Received backtest request for {Ticker}, Strategy: {Strategy}, Period: {StartDate} to {EndDate}",
                request.Ticker, request.StrategyName, request.StartDate.ToShortDateString(), request.EndDate.ToShortDateString());

            // --- Call the Backtesting Service ---
            BacktestResult? result = await _backtestingService.RunBacktestAsync(
                request.Ticker,
                request.StartDate,
                request.EndDate,
                request.StrategyName,
                request.InitialCapital,
                request.Parameters
            );

            // --- Handle Service Response ---
            if (result == null) // Should ideally not happen if service handles errors internally
            {
                _logger.LogError("Backtest service unexpectedly returned null for {Ticker}, Strategy: {Strategy}", request.Ticker, request.StrategyName);
                return StatusCode(StatusCodes.Status500InternalServerError, "An unexpected error occurred during backtesting.");
            }

            if (!string.IsNullOrEmpty(result.ErrorMessage))
            {
                _logger.LogWarning("Backtest for {Ticker}, Strategy: {Strategy} completed with error: {Error}", request.Ticker, request.StrategyName, result.ErrorMessage);
                // Decide on appropriate status code based on error message content
                 if (result.ErrorMessage.Contains("fetch", StringComparison.OrdinalIgnoreCase) || result.ErrorMessage.Contains("data available", StringComparison.OrdinalIgnoreCase))
                 {
                      // Could be 404 if data truly not found, or 503 if fetching failed
                      return NotFound(result.ErrorMessage); // Or Ok(result) if partial results are acceptable
                 }
                 if (result.ErrorMessage.Contains("Configuration error", StringComparison.OrdinalIgnoreCase) || result.ErrorMessage.Contains("parameter", StringComparison.OrdinalIgnoreCase))
                 {
                     return BadRequest(result.ErrorMessage); // Or Ok(result)
                 }
                 // Default to Ok(result) to return the error message within the response body
                return Ok(result);
            }

             // Success case
             _logger.LogInformation("Backtest completed successfully for {Ticker}, Strategy: {Strategy}. Final Value: {FinalValue}",
                request.Ticker, request.StrategyName, result.Metrics?.FinalPortfolioValue);
            return Ok(result);
        }
        // --- Exception Handling ---
        // Catch specific exceptions that might bubble up if not handled in service
        catch (ArgumentException ex) // E.g., strategy not found by factory
        {
            _logger.LogWarning(ex, "Invalid argument during backtest request for {Ticker}, Strategy: {Strategy}", request.Ticker, request.StrategyName);
            return BadRequest(ex.Message);
        }
        catch (HttpRequestException ex) // E.g., data fetching network error not caught by service
        {
             _logger.LogError(ex, "HTTP request error during backtest processing for {Ticker}", request.Ticker);
            // 503 Service Unavailable is appropriate if an external dependency failed
            return StatusCode(StatusCodes.Status503ServiceUnavailable, "A required external service is unavailable. Please try again later.");
        }
        catch (Exception ex) // Catch-all for unexpected errors
        {
            _logger.LogError(ex, "An unexpected error occurred while processing the backtest request for {Ticker}, Strategy: {Strategy}", request.Ticker, request.StrategyName);
            // Return a generic error to the client for security
            return StatusCode(StatusCodes.Status500InternalServerError, "An internal server error occurred. Please contact support if the problem persists.");
        }
    }
}
EOF

cat << 'EOF' > Controllers/LLMController.cs
using Microsoft.AspNetCore.Mvc;
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Services;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace TradingSimulatorAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LLMController : ControllerBase
{
    private readonly ILLMService _llmService;
    private readonly ILogger<LLMController> _logger;

    public LLMController(ILLMService llmService, ILogger<LLMController> logger)
    {
        _llmService = llmService;
        _logger = logger;
    }

    /// <summary>
    /// Sends a question to the configured Language Model (LLM) for assistance.
    /// </summary>
    /// <param name="request">The question, optional context, and conversation history.</param>
    /// <returns>The LLM's response or an error.</returns>
    [HttpPost("ask")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(LLMResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest)] // For invalid input
    [ProducesResponseType(StatusCodes.Status500InternalServerError)] // For LLM service errors
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)] // If LLM API is down
    public async Task<ActionResult<LLMResponse>> AskLLM([FromBody] LLMRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Question))
        {
            return BadRequest("Question cannot be empty.");
        }

         _logger.LogInformation("Received LLM ask request."); // Avoid logging full question/context unless needed for debugging

        try
        {
            LLMResponse response = await _llmService.AskAsync(request);

            if (!string.IsNullOrEmpty(response.Error))
            {
                _logger.LogWarning("LLM service returned an error: {Error}", response.Error);
                 // Decide status code based on error type
                 if (response.Error.Contains("API request failed", StringComparison.OrdinalIgnoreCase))
                 {
                     return StatusCode(StatusCodes.Status503ServiceUnavailable, response); // Return error in body
                 }
                 // Default to 500 for unexpected internal LLM service errors
                return StatusCode(StatusCodes.Status500InternalServerError, response);
            }

             _logger.LogInformation("LLM request processed successfully.");
            return Ok(response);
        }
         catch (InvalidOperationException ex) // E.g., LLM service not configured
        {
             _logger.LogError(ex, "LLM service configuration error.");
             return StatusCode(StatusCodes.Status500InternalServerError, new LLMResponse { Error = "LLM service is not configured correctly." });
        }
        catch (Exception ex) // Catch-all for unexpected errors during the call
        {
            _logger.LogError(ex, "An unexpected error occurred while communicating with the LLM service.");
            return StatusCode(StatusCodes.Status500InternalServerError, new LLMResponse { Error = "An internal error occurred while processing your request." });
        }
    }
}
EOF

cat << 'EOF' > Controllers/DataController.cs
using Microsoft.AspNetCore.Mvc;
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Services;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DataController : ControllerBase
{
    private readonly StrategyFactory _strategyFactory;

    public DataController(StrategyFactory strategyFactory)
    {
        _strategyFactory = strategyFactory;
    }

    /// <summary>
    /// Gets a list of available trading strategies.
    /// </summary>
    /// <returns>A list of StrategyInfo objects.</returns>
    [HttpGet("strategies")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IEnumerable<StrategyInfo>))]
    public ActionResult<IEnumerable<StrategyInfo>> GetAvailableStrategies()
    {
        var strategies = _strategyFactory.GetAllStrategyInfos();
        return Ok(strategies);
    }

    // Add other data-related endpoints if needed (e.g., list available tickers - though this is complex)
}
EOF

# --- Add common .NET packages ---
echo "[INFO] Adding common .NET packages..."
# For OpenAI (using Azure SDK which works for both Azure OpenAI and OpenAI directly)
dotnet add package Azure.AI.OpenAI
# For Yahoo Finance Data (Check current status/alternatives like AlphaVantage, Polygon.io etc)
dotnet add package YahooFinanceApi
# For Math calculations (Standard Deviation etc.) - Can often use basic Linq/Math instead
# dotnet add package MathNet.Numerics
# For reading configuration strongly typed
dotnet add package Microsoft.Extensions.Options.ConfigurationExtensions

if [ $? -ne 0 ]; then echo "[WARNING] dotnet add package failed. Check package names and internet connection."; fi

# --- Create basic .NET .gitignore ---
echo "[INFO] Writing .gitignore for backend..."
cat << 'EOF' > .gitignore
# Standard VS/dotnet cache and settings files
[Bb]in/
[Oo]bj/
.vs/
.vscode/
*.user
*.suo
*.sln.docstates

# Build results
[Rr]elease/
[Dd]ebug/
artifacts/
testresults/

# Rider specific
.idea/
*.idea.*

# User Secrets
**/secrets.json

# Environment settings that might contain secrets
appsettings.*.json
!appsettings.Template.json # Example: Keep template files

# Publish artifacts
publish/
*.Publish.xml

# Tooling
tools/

# OS generated files
.DS_Store
Thumbs.db

# Optional: Log files
*.log
logs/

# Optional: Local databases (if using SQLite etc.)
*.db
*.db-journal
EOF


# --- Return to root directory ---
cd ..
echo "[INFO] Finished backend setup."


# =====================================================
#           FRONTEND (React + TypeScript)
# =====================================================
FRONTEND_DIR="trading-simulator-ui"
echo "[INFO] Setting up React frontend in $FRONTEND_DIR..."

# Use create-react-app for the base structure
# Add --use-npm or --use-yarn if needed, defaults usually to npm if available
npx create-react-app "$FRONTEND_DIR" --template typescript
if [ $? -ne 0 ]; then echo "[ERROR] create-react-app failed. Ensure Node.js, npm/yarn are installed."; exit 1; fi

cd "$FRONTEND_DIR" || { echo "Failed to enter frontend directory $FRONTEND_DIR"; exit 1; }
echo "[INFO] Base React project created."

# Create additional directories within src/
mkdir -p src/components src/hooks src/services src/types src/contexts
echo "[INFO] Created frontend directories: src/components, src/hooks, src/services, src/types, src/contexts"

# --- Write frontend TypeScript/TSX files ---

# --- Types ---
echo "[INFO] Writing src/types/index.ts..."
cat << 'EOF' > src/types/index.ts
// Shared types between frontend and backend (match C# DTOs)

// Corresponds to Models/PerformanceMetrics.cs
export interface PerformanceMetrics {
  initialCapital: number;
  finalPortfolioValue: number;
  totalReturnPercent: number;
  annualizedReturnPercent: number;
  sharpeRatio: number;
  maxDrawdownPercent: number;
  numberOfTradePairs: number;
}

// Corresponds to Models/TradeLogEntry.cs
export interface TradeLogEntry {
  date: string; // ISO date string
  action: 'BUY' | 'SELL';
  price: number;
  shares: number;
  cost?: number; // Present for BUY
  proceeds?: number; // Present for SELL
  commission?: number; // Optional
}

// Corresponds to Models/ChartDataPoint.cs
export interface ChartDataPoint {
    date: string; // ISO date string (e.g., "2023-10-27T00:00:00Z") or Date object parsable string
    value: number;
}

// Corresponds to Models/BacktestResult.cs
export interface BacktestResult {
  strategyName: string;
  ticker: string;
  startDate: string; // ISO date string
  endDate: string; // ISO date string
  metrics: PerformanceMetrics | null;
  portfolioValueHistory: ChartDataPoint[];
  benchmarkValueHistory: ChartDataPoint[]; // Normalized benchmark price
  tradeLog: TradeLogEntry[];
  errorMessage?: string; // If backtest failed on the backend
  // signalsData?: any[]; // Optional: Raw data with signals for advanced plotting
}

// Corresponds to Models/BacktestRequest.cs (for sending)
export interface BacktestRequest {
  ticker: string;
  startDate: string; // Format: YYYY-MM-DD
  endDate: string; // Format: YYYY-MM-DD
  strategyName: string;
  initialCapital: number;
  parameters?: Record<string, any>; // Strategy-specific parameters { key: value }
}

// Corresponds to Models/StrategyInfo.cs
export interface StrategyInfo {
    name: string; // Internal name used in API calls
    displayName: string; // User-friendly name
    description: string;
    // Optional: Define parameter structure if needed on frontend
    parameters?: Record<string, { type: string; description: string; defaultValue?: any }>;
}

// For LLM Interaction (Matches C# Models)
export interface ChatMessage {
    role: 'user' | 'assistant' | 'system'; // Align with backend roles
    content: string;
}
export interface LLMRequest {
    question: string;
    context?: string;
    conversationHistory?: ChatMessage[];
}
export interface LLMResponse {
    answer: string;
    updatedConversationHistory?: ChatMessage[];
    error?: string; // Handle potential errors from LLM service
}

// General API Error structure (from api.ts helper)
export interface ApiError {
    message: string;
    statusCode?: number;
    details?: any; // Can contain validation errors etc.
}
EOF

# --- Services ---
echo "[INFO] Writing src/services/api.ts..."
cat << 'EOF' > src/services/api.ts
import axios, { AxiosError } from 'axios';
import {
    BacktestRequest,
    BacktestResult,
    StrategyInfo,
    LLMRequest,
    LLMResponse,
    ApiError,
    ChatMessage // Import ChatMessage if using history
} from '../types';

// Configure base URL for the API
// Use environment variables set by CRA build process (.env files)
const API_BASE_URL = process.env.REACT_APP_API_URL || 'https://localhost:7123/api'; // Default for local dev
console.log(`API Base URL configured to: ${API_BASE_URL}`); // Log for debugging

const apiClient = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json',
    },
    // Optional: Timeout configuration
    // timeout: 10000, // 10 seconds timeout
});

// --- Helper for Error Handling ---
// Parses Axios errors into a more consistent ApiError structure
const handleApiError = (error: unknown): ApiError => {
    if (axios.isAxiosError(error)) {
        const axiosError = error as AxiosError<any>; // Use 'any' for potential non-standard error shapes
        console.error('API Error:', axiosError.response?.status, axiosError.response?.data, axiosError.config?.url);

        let message = 'An API error occurred.';
        // Try to extract meaningful error message from response body
        // ASP.NET validation errors often in `errors` or `title`
        if (axiosError.response?.data) {
            if (typeof axiosError.response.data === 'string') {
                message = axiosError.response.data;
            } else if (axiosError.response.data.message) {
                message = axiosError.response.data.message;
            } else if (axiosError.response.data.title) { // ASP.NET ProblemDetails title
                 message = axiosError.response.data.title;
                 // Include validation errors if present
                if (axiosError.response.data.errors) {
                     const validationErrors = Object.entries(axiosError.response.data.errors)
                         .map(([field, errors]) => `${field}: ${(errors as string[]).join(', ')}`)
                         .join('; ');
                     if(validationErrors) message += ` (${validationErrors})`;
                }
            }
        } else if (axiosError.message) { // Fallback to Axios error message
             message = axiosError.message;
        }

        return {
            message: message,
            statusCode: axiosError.response?.status,
            details: axiosError.response?.data // Include full details for potential debugging
        };
    } else {
        // Handle non-Axios errors (e.g., network issues before request is sent, code errors)
        console.error('Unexpected Error in API call:', error);
        return {
            message: error instanceof Error ? error.message : 'An unexpected error occurred',
        };
    }
};


// --- API Functions ---

/**
 * Fetches the list of available trading strategies from the backend.
 */
export const getStrategies = async (): Promise<StrategyInfo[]> => {
    try {
        console.debug('API Call: GET /data/strategies');
        const response = await apiClient.get<StrategyInfo[]>('/data/strategies');
        console.debug('API Response: GET /data/strategies - Success', response.data);
        return response.data;
    } catch (error) {
        console.error('API Error: GET /data/strategies');
        throw handleApiError(error); // Throw consistent error object
    }
};

/**
 * Runs a backtest simulation via the backend API.
 */
export const runBacktest = async (request: BacktestRequest): Promise<BacktestResult> => {
    console.debug('API Call: POST /backtest/run', request);
    try {
        const response = await apiClient.post<BacktestResult>('/backtest/run', request);
        console.debug('API Response: POST /backtest/run - Success'); // Avoid logging full result data unless necessary
        return response.data;
    } catch (error) {
        console.error('API Error: POST /backtest/run');
        throw handleApiError(error);
    }
};


/**
 * Sends a question to the LLM guide via the backend API.
 */
export const askLLM = async (request: LLMRequest): Promise<LLMResponse> => {
    console.debug('API Call: POST /llm/ask', { questionLength: request.question.length, contextProvided: !!request.context }); // Log less sensitive info
    try {
        const response = await apiClient.post<LLMResponse>('/llm/ask', request);
        console.debug('API Response: POST /llm/ask - Success');
        return response.data;
    } catch (error) {
        console.error('API Error: POST /llm/ask');
        throw handleApiError(error);
    }
};
EOF

# --- Components ---
echo "[INFO] Writing src/components/LoadingSpinner.tsx..."
cat << 'EOF' > src/components/LoadingSpinner.tsx
import React from 'react';
import './LoadingSpinner.css'; // We'll define styles here or in App.css

const LoadingSpinner: React.FC = () => {
    return (
        <div className="loading-spinner-overlay">
            <div className="loading-spinner"></div>
        </div>
    );
};

export default LoadingSpinner;
EOF

echo "[INFO] Writing src/components/ControlPanel.tsx..."
cat << 'EOF' > src/components/ControlPanel.tsx
import React, { useState, useEffect, useCallback, ChangeEvent } from 'react';
import { BacktestRequest, StrategyInfo, BacktestResult, ApiError } from '../types';
import { getStrategies, runBacktest } from '../services/api';

interface ControlPanelProps {
    onBacktestStart: () => void;
    onBacktestComplete: (results: BacktestResult | null, error?: ApiError) => void;
    isLoading: boolean; // To disable inputs while loading
}

const ControlPanel: React.FC<ControlPanelProps> = ({ onBacktestStart, onBacktestComplete, isLoading }) => {
    // --- State ---
    const [ticker, setTicker] = useState<string>('^GSPC'); // Default to S&P 500
    const [startDate, setStartDate] = useState<string>('2020-01-01'); // Default start
    const [endDate, setEndDate] = useState<string>(() => new Date().toISOString().split('T')[0]); // Default end (today)
    const [initialCapital, setInitialCapital] = useState<number>(100000);
    const [availableStrategies, setAvailableStrategies] = useState<StrategyInfo[]>([]);
    const [selectedStrategy, setSelectedStrategy] = useState<string>('');
    const [strategyDescription, setStrategyDescription] = useState<string>('');
    const [fetchStrategiesError, setFetchStrategiesError] = useState<string>('');
    const [validationError, setValidationError] = useState<string>('');

    // --- Effects ---

    // Fetch strategies on component mount
    useEffect(() => {
        let isMounted = true; // Prevent state update on unmounted component
        const fetchStrategies = async () => {
            setFetchStrategiesError('');
            try {
                const strategies = await getStrategies();
                if (isMounted) {
                    if (strategies && strategies.length > 0) {
                        setAvailableStrategies(strategies);
                        // Set default selected strategy only if not already set or invalid
                        if (!selectedStrategy || !strategies.some(s => s.name === selectedStrategy)) {
                            setSelectedStrategy(strategies[0].name);
                        }
                    } else {
                        setFetchStrategiesError('No strategies returned from API.');
                    }
                }
            } catch (error: any) {
                console.error("Failed to fetch strategies:", error);
                if (isMounted) {
                    setFetchStrategiesError(`Failed to load strategies: ${error.message || 'Unknown error'}`);
                }
            }
        };
        fetchStrategies();
        return () => { isMounted = false; }; // Cleanup function
    }, []); // Empty dependency array means run once on mount

    // Update strategy description when selectedStrategy or availableStrategies changes
    useEffect(() => {
        const currentStrategy = availableStrategies.find(s => s.name === selectedStrategy);
        setStrategyDescription(currentStrategy?.description || '');
    }, [selectedStrategy, availableStrategies]);

    // --- Event Handlers ---

    const handleInputChange = (setter: React.Dispatch<React.SetStateAction<string | number>>) =>
        (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        setter(e.target.value);
        setValidationError(''); // Clear validation error on input change
    };

     const handleCapitalChange = (e: ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        // Allow empty input or positive numbers
        if (value === '' || /^[0-9]*\.?[0-9]*$/.test(value)) {
            setInitialCapital(value === '' ? 0 : parseFloat(value)); // Store as number
             setValidationError('');
        }
    };

    // Validate inputs before running backtest
    const validateInputs = (): boolean => {
        if (!ticker.trim()) {
            setValidationError('Ticker symbol cannot be empty.');
            return false;
        }
         if (!startDate || !endDate) {
            setValidationError('Start date and end date are required.');
            return false;
        }
        if (new Date(startDate) >= new Date(endDate)) {
            setValidationError('Start date must be before end date.');
            return false;
        }
         if (initialCapital <= 0) {
             setValidationError('Initial capital must be a positive number.');
            return false;
         }
        if (!selectedStrategy) {
            setValidationError('Please select a strategy.');
            return false;
        }
        setValidationError(''); // Clear error if validation passes
        return true;
    };


    // Handle backtest execution submit
    const handleRunBacktest = useCallback(async (event: React.FormEvent) => {
        event.preventDefault(); // Prevent default form submission

        if (!validateInputs() || isLoading) {
            return; // Don't run if validation fails or already loading
        }

        onBacktestStart(); // Notify parent component loading started

        const request: BacktestRequest = {
            ticker: ticker.trim().toUpperCase(), // Normalize ticker
            startDate: startDate,
            endDate: endDate,
            strategyName: selectedStrategy,
            initialCapital: Number(initialCapital), // Ensure it's a number
            parameters: {} // TODO: Add UI elements to collect strategy-specific parameters
        };

        try {
            const results = await runBacktest(request);
            onBacktestComplete(results); // Pass results (potentially including backend error msg)
        } catch (error) {
            // Catch errors thrown by the handleApiError helper in api.ts
            console.error("Backtest API call failed:", error);
            onBacktestComplete(null, error as ApiError); // Pass the structured API error
        }
    }, [ticker, startDate, endDate, selectedStrategy, initialCapital, isLoading, onBacktestStart, onBacktestComplete]); // Include all dependencies


    // --- Render ---
    return (
        // Use a form element for better accessibility and potential submit handling
        <form onSubmit={handleRunBacktest} className="control-panel card">
            <h2>Simulation Controls</h2>

            {fetchStrategiesError && <p className="error-message">Error loading strategies: {fetchStrategiesError}</p>}
            {validationError && <p className="error-message validation-error">{validationError}</p>}

            {/* Ticker Input */}
            <div className="form-group">
                <label htmlFor="ticker">Ticker / Symbol:</label>
                <input
                    id="ticker"
                    type="text"
                    value={ticker}
                    onChange={handleInputChange(setTicker)}
                    placeholder="e.g., AAPL, ^GSPC"
                    disabled={isLoading}
                    required // Basic HTML5 validation
                    aria-describedby={validationError && validationError.includes('Ticker') ? 'ticker-error' : undefined}
                />
                 {validationError && validationError.includes('Ticker') && <span id="ticker-error" className="validation-error-inline">{validationError}</span>}
            </div>

            {/* Date Inputs */}
            <div className="form-group date-group">
                 <div>
                    <label htmlFor="start-date">Start Date:</label>
                    <input
                        id="start-date"
                        type="date"
                        value={startDate}
                        onChange={handleInputChange(setStartDate)}
                        disabled={isLoading}
                        required
                        max={endDate} // Basic HTML5 validation constraint
                        aria-describedby={validationError && validationError.includes('date') ? 'date-error' : undefined}
                    />
                 </div>
                 <div>
                    <label htmlFor="end-date">End Date:</label>
                    <input
                        id="end-date"
                        type="date"
                        value={endDate}
                        onChange={handleInputChange(setEndDate)}
                        disabled={isLoading}
                        required
                        min={startDate} // Basic HTML5 validation constraint
                        max={new Date().toISOString().split('T')[0]} // Prevent future dates
                        aria-describedby={validationError && validationError.includes('date') ? 'date-error' : undefined}
                    />
                 </div>
            </div>
             {validationError && validationError.includes('date') && <span id="date-error" className="validation-error-inline">{validationError}</span>}


            {/* Initial Capital Input */}
            <div className="form-group">
                <label htmlFor="initial-capital">Initial Capital ($):</label>
                <input
                    id="initial-capital"
                    type="number" // Use number type for better mobile keyboards
                    value={initialCapital} // Control component value
                    onChange={handleCapitalChange}
                    min="1" // HTML5 validation
                    step="any" // Allow decimals if needed, or "1000" etc.
                    placeholder="e.g., 100000"
                    disabled={isLoading}
                    required
                    aria-describedby={validationError && validationError.includes('capital') ? 'capital-error' : undefined}
                />
                 {validationError && validationError.includes('capital') && <span id="capital-error" className="validation-error-inline">{validationError}</span>}
            </div>

            {/* Strategy Selection */}
            <div className="form-group">
                <label htmlFor="strategy">Strategy:</label>
                <select
                    id="strategy"
                    value={selectedStrategy}
                    onChange={handleInputChange(setSelectedStrategy)}
                    disabled={isLoading || availableStrategies.length === 0 || !!fetchStrategiesError}
                    required
                    aria-describedby={validationError && validationError.includes('strategy') ? 'strategy-error' : undefined}
                >
                    {/* Placeholder option */}
                    {!selectedStrategy && <option value="" disabled>Select a strategy</option>}
                    {/* Loading/Error states */}
                    {fetchStrategiesError && <option value="" disabled>Error loading strategies</option>}
                    {availableStrategies.length === 0 && !fetchStrategiesError && <option value="" disabled>Loading...</option>}

                    {/* Strategy options */}
                    {availableStrategies.map(strategy => (
                        <option key={strategy.name} value={strategy.name}>
                            {strategy.displayName}
                        </option>
                    ))}
                </select>
                {strategyDescription && <p className="strategy-description">{strategyDescription}</p>}
                {/* TODO: Add dynamic inputs based on selectedStrategy.parameters here */}
                 {validationError && validationError.includes('strategy') && <span id="strategy-error" className="validation-error-inline">{validationError}</span>}
            </div>

            {/* Submit Button */}
            <button
                type="submit" // Important for form submission handling
                disabled={isLoading || !selectedStrategy || availableStrategies.length === 0 || !!fetchStrategiesError || !!validationError}
                className="run-button"
            >
                {isLoading ? 'Running Simulation...' : 'Run Backtest'}
            </button>
        </form>
    );
};

export default ControlPanel;
EOF

echo "[INFO] Writing src/components/ResultsDisplay.tsx..."
cat << 'EOF' > src/components/ResultsDisplay.tsx
import React from 'react';
import { BacktestResult, PerformanceMetrics } from '../types';
import './ResultsDisplay.css'; // For specific styling

interface ResultsDisplayProps {
    results: BacktestResult | null;
}

// Helper to format numbers nicely
const formatNumber = (num: number | null | undefined, digits: number = 2, isPercent: boolean = false): string => {
    if (num === null || typeof num === 'undefined' || isNaN(num)) {
        return 'N/A';
    }
    const formatted = num.toFixed(digits);
    return isPercent ? `${formatted}%` : formatted;
};

// Helper to format currency
const formatCurrency = (num: number | null | undefined, digits: number = 2): string => {
     if (num === null || typeof num === 'undefined' || isNaN(num)) {
        return 'N/A';
    }
    return `$${num.toLocaleString(undefined, { minimumFractionDigits: digits, maximumFractionDigits: digits })}`;
}

const ResultsDisplay: React.FC<ResultsDisplayProps> = ({ results }) => {
    if (!results || !results.metrics) {
        // Don't render anything or show a placeholder if no results yet
        // This component expects valid results to be passed
        return null;
    }

    const { metrics, ticker, strategyName, startDate, endDate } = results;

    return (
        <div className="results-display card">
            <h2>Backtest Results</h2>
            <p className="results-summary">
                Strategy: <strong>{strategyName}</strong> on <strong>{ticker}</strong><br />
                Period: {new Date(startDate).toLocaleDateString()} to {new Date(endDate).toLocaleDateString()}
            </p>

            {metrics ? (
                <ul className="metrics-list">
                    <li>
                        <strong>Initial Capital:</strong>
                        <span>{formatCurrency(metrics.initialCapital)}</span>
                    </li>
                    <li>
                        <strong>Final Portfolio Value:</strong>
                        <span>{formatCurrency(metrics.finalPortfolioValue)}</span>
                    </li>
                    <li className={metrics.totalReturnPercent >= 0 ? 'positive' : 'negative'}>
                        <strong>Total Return:</strong>
                        <span>{formatNumber(metrics.totalReturnPercent, 2, true)}</span>
                    </li>
                    <li className={metrics.annualizedReturnPercent >= 0 ? 'positive' : 'negative'}>
                        <strong>Annualized Return (CAGR):</strong>
                        <span>{formatNumber(metrics.annualizedReturnPercent, 2, true)}</span>
                    </li>
                     <li>
                        <strong>Sharpe Ratio (Annualized):</strong>
                        <span>{formatNumber(metrics.sharpeRatio, 3)}</span>
                    </li>
                     <li className={metrics.maxDrawdownPercent <= -10 ? 'negative' : (metrics.maxDrawdownPercent <= -5 ? 'warning' : 'positive')}>
                        <strong>Max Drawdown:</strong>
                        <span>{formatNumber(metrics.maxDrawdownPercent, 2, true)}</span>
                    </li>
                    <li>
                        <strong>Trade Pairs (Approx):</strong>
                        <span>{metrics.numberOfTradePairs ?? 'N/A'}</span>
                    </li>

                </ul>
            ) : (
                <p>Performance metrics are unavailable.</p>
            )}

            {/* Optional: Display Trade Log Summary or Full Log */}
            {/*
            <h3>Trade Log Summary</h3>
            <p>Total Trades: {results.tradeLog?.length ?? 0}</p>
            <p>Buy Trades: {results.tradeLog?.filter(t => t.action === 'BUY').length ?? 0}</p>
            <p>Sell Trades: {results.tradeLog?.filter(t => t.action === 'SELL').length ?? 0}</p>
            */}

             {/* Optional: Display disclaimer again */}
             <p className="results-disclaimer">
                 Note: Simulation ignores commissions, slippage, taxes, and other real-world costs. Past performance is not indicative of future results.
             </p>
        </div>
    );
};

export default ResultsDisplay;
EOF

echo "[INFO] Writing src/components/ChartDisplay.tsx..."
cat << 'EOF' > src/components/ChartDisplay.tsx
import React, { useRef, useEffect } from 'react';
import { BacktestResult, ChartDataPoint } from '../types';
import {
    Chart as ChartJS,
    CategoryScale, // x axis
    LinearScale, // y axis
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend,
    TimeScale, // Use TimeScale for date axes
    ChartOptions,
    ChartData
} from 'chart.js';
import 'chartjs-adapter-date-fns'; // Import adapter for date handling
import { Line } from 'react-chartjs-2';

// Register Chart.js components
ChartJS.register(
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend,
    TimeScale // Register TimeScale
);

interface ChartDisplayProps {
    results: BacktestResult | null;
}

// Helper function to format chart data points
const formatChartData = (dataPoints: ChartDataPoint[]) => {
    return dataPoints.map(point => ({
        x: new Date(point.date).getTime(), // Use timestamp for time scale
        y: point.value
    }));
};


const ChartDisplay: React.FC<ChartDisplayProps> = ({ results }) => {
    const chartRef = useRef<ChartJS<'line'>>(null);

    if (!results || !results.portfolioValueHistory || !results.benchmarkValueHistory) {
        return <div className="chart-display card"><p>Chart data is unavailable.</p></div>;
    }

    const { portfolioValueHistory, benchmarkValueHistory, ticker, strategyName } = results;

    // Prepare data for Chart.js
    const chartData: ChartData<'line'> = {
         // Labels are often inferred by time scale, but can be provided if needed
        // labels: portfolioValueHistory.map(p => new Date(p.date)), // Use Date objects for time scale
        datasets: [
            {
                label: `${strategyName} Portfolio Value`,
                data: formatChartData(portfolioValueHistory),
                borderColor: 'rgb(54, 162, 235)', // Blue
                backgroundColor: 'rgba(54, 162, 235, 0.5)',
                tension: 0.1, // Slightly curve the line
                pointRadius: 0, // Hide points for cleaner line
                borderWidth: 2,
                yAxisID: 'y', // Assign to the primary y-axis
            },
            {
                label: `${ticker} Benchmark (Normalized)`,
                data: formatChartData(benchmarkValueHistory),
                borderColor: 'rgb(150, 150, 150)', // Grey
                backgroundColor: 'rgba(150, 150, 150, 0.5)',
                borderDash: [5, 5], // Dashed line for benchmark
                tension: 0.1,
                pointRadius: 0,
                borderWidth: 1.5,
                 yAxisID: 'y', // Assign to the primary y-axis (since it's normalized)
            },
             // Optional: Add buy/sell markers if signal data is available
            // {
            //     label: 'Buy Signals',
            //     data: buySignalPoints, // formatChartData(points where signal=1)
            //     borderColor: 'rgba(75, 192, 192, 0)', // Transparent line
            //     backgroundColor: 'rgba(75, 192, 192, 1)', // Green points
            //     pointStyle: 'triangle',
            //     pointRadius: 6,
            //     pointRotation: 0, // Pointing up
            //     showLine: false, // Don't connect points with a line
            // },
            // {
            //     label: 'Sell Signals',
            //     data: sellSignalPoints, // formatChartData(points where signal=-1)
            //     borderColor: 'rgba(255, 99, 132, 0)', // Transparent line
            //     backgroundColor: 'rgba(255, 99, 132, 1)', // Red points
            //     pointStyle: 'triangle',
            //     pointRadius: 6,
            //     pointRotation: 180, // Pointing down
            //     showLine: false,
            // }
        ],
    };

    // Configure chart options
    const options: ChartOptions<'line'> = {
        responsive: true,
        maintainAspectRatio: false, // Allow chart to fill container height
        plugins: {
            legend: {
                position: 'top' as const,
            },
            title: {
                display: true,
                text: `Strategy Performance vs Benchmark (${ticker})`,
                font: { size: 16 }
            },
            tooltip: {
                mode: 'index' as const, // Show tooltips for all datasets at the same x-index
                intersect: false,
                callbacks: {
                     label: function(context) {
                        let label = context.dataset.label || '';
                        if (label) {
                            label += ': ';
                        }
                        if (context.parsed.y !== null) {
                            // Format as currency
                            label += new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(context.parsed.y);
                        }
                        return label;
                    }
                }
            },
        },
        scales: {
            x: {
                type: 'time' as const, // Use time scale
                time: {
                    unit: 'month' as const, // Display months on the axis, adjust as needed ('day', 'year')
                    tooltipFormat: 'PP' // Date format for tooltip (e.g., 'Oct 27, 2023') - Uses date-fns formats
                },
                title: {
                    display: true,
                    text: 'Date'
                },
                grid: {
                     display: false // Hide vertical grid lines if desired
                }
            },
            y: { // Primary Y-axis for portfolio/benchmark value
                type: 'linear' as const,
                display: true,
                position: 'left' as const,
                title: {
                    display: true,
                    text: 'Value ($)'
                },
                 // Format ticks as currency
                 ticks: {
                     callback: function(value, index, values) {
                         if (typeof value === 'number') {
                             return '$' + value.toLocaleString();
                         }
                         return value;
                     }
                 }
            }
            // Optional: Add a secondary Y-axis if needed for indicators like RSI
            // y1: {
            //    type: 'linear' as const,
            //    display: true, // Set to true if you have data for it
            //    position: 'right' as const,
            //    title: { display: true, text: 'RSI' },
            //    grid: { drawOnChartArea: false }, // Only show grid for primary axis
            //    min: 0, max: 100 // Typical RSI range
            // }
        },
         interaction: {
            mode: 'index' as const,
            intersect: false,
        },
    };

    // Destroy previous chart instance when results change
     useEffect(() => {
        const chart = chartRef.current;
        return () => {
            chart?.destroy();
        };
    }, [results]); // Dependency on results ensures cleanup when new results arrive

    return (
        <div className="chart-display card">
            <div style={{ position: 'relative', height: '400px' }}> {/* Set container height */}
                <Line ref={chartRef} options={options} data={chartData} />
            </div>
        </div>
    );
};

export default ChartDisplay;
EOF

echo "[INFO] Writing src/components/LLMChat.tsx..."
cat << 'EOF' > src/components/LLMChat.tsx
import React, { useState, useCallback, useRef, useEffect } from 'react';
import { LLMRequest, LLMResponse, ChatMessage, ApiError } from '../types';
import { askLLM } from '../services/api';
import './LLMChat.css'; // For specific styling

interface LLMChatProps {
    // Function to get current context (e.g., from backtest results)
    contextProvider: () => string;
}

const LLMChat: React.FC<LLMChatProps> = ({ contextProvider }) => {
    const [conversation, setConversation] = useState<ChatMessage[]>([]);
    const [currentQuestion, setCurrentQuestion] = useState<string>('');
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [error, setError] = useState<string>('');
    const chatHistoryRef = useRef<HTMLDivElement>(null); // Ref for scrolling

    // Scroll to bottom of chat history whenever conversation updates
    useEffect(() => {
        if (chatHistoryRef.current) {
            chatHistoryRef.current.scrollTop = chatHistoryRef.current.scrollHeight;
        }
    }, [conversation]);

    const handleAskQuestion = useCallback(async (event?: React.FormEvent) => {
        event?.preventDefault(); // Prevent form submission if used in a form
        const question = currentQuestion.trim();
        if (!question || isLoading) {
            return;
        }

        setIsLoading(true);
        setError('');

        // Add user question immediately to the displayed history
        const newUserMessage: ChatMessage = { role: 'user', content: question };
        setConversation(prev => [...prev, newUserMessage]);
        setCurrentQuestion(''); // Clear input field

        // Get current context
        const currentContext = contextProvider();

        // Prepare request for the API
        const request: LLMRequest = {
            question: question,
            context: currentContext || undefined, // Send context if available
            // Send recent history (optional, depends on backend capability & token limits)
            // Limit history length sent to backend to avoid excessive token usage
            conversationHistory: conversation.slice(-6) // Send last 3 user/assistant pairs
        };

        try {
            const response = await askLLM(request);

            if (response.error) {
                setError(`LLM Error: ${response.error}`);
                // Optionally remove the user's message if the request failed badly?
            } else {
                 const assistantMessage: ChatMessage = { role: 'assistant', content: response.answer };
                 // Update conversation with assistant's reply
                 // If backend returns updated history, use that. Otherwise, just append.
                 if (response.updatedConversationHistory) {
                     // Be careful here - ensure roles match expectations ('user', 'assistant')
                     // This assumes backend returns the full relevant history including the latest exchange
                     // setConversation(response.updatedConversationHistory); // Replace history entirely
                      // Safer: Just append the new assistant message if backend doesn't manage full history
                       setConversation(prev => [...prev, assistantMessage]);
                 } else {
                      setConversation(prev => [...prev, assistantMessage]);
                 }
            }
        } catch (apiError) {
            console.error("Failed to ask LLM:", apiError);
            const error = apiError as ApiError; // Type assertion
            setError(`API Error: ${error.message || 'Failed to get response from guide.'}`);
             // Optionally: Add an error message as an assistant response?
             // const errorMessage: ChatMessage = { role: 'assistant', content: `Sorry, I encountered an error: ${error.message}` };
             // setConversation(prev => [...prev, errorMessage]);
        } finally {
            setIsLoading(false);
        }
    }, [currentQuestion, isLoading, contextProvider, conversation]); // Include conversation in dependencies if sending history

    // Allow sending question with Enter key in textarea
    const handleKeyDown = (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
        if (event.key === 'Enter' && !event.shiftKey) { // Send on Enter, allow Shift+Enter for newline
            event.preventDefault();
            handleAskQuestion();
        }
    };

     const handleReset = () => {
        setConversation([]);
        setError('');
        setCurrentQuestion('');
        setIsLoading(false);
        // Optionally: Call a backend endpoint to reset server-side history if needed
        console.log("LLM conversation reset.");
    };


    return (
        <div className="llm-chat card">
            <h2>Trading Strategy Guide (LLM)</h2>
             <p className="guide-description">
                Ask questions about trading concepts, the loaded strategy, or the backtest results.
                Context from the latest results (if available) will be provided automatically.
            </p>

            {/* Chat History Display */}
            <div className="chat-history" ref={chatHistoryRef}>
                {conversation.map((msg, index) => (
                    <div key={index} className={`chat-message ${msg.role}-message`}>
                        {/* Simple text display, consider Markdown rendering for formatted responses */}
                        {msg.content.split('\n').map((line, i) => <p key={i}>{line}</p>)}
                    </div>
                ))}
                {isLoading && <div className="chat-message assistant-message loading-dots"><span>.</span><span>.</span><span>.</span></div>}
                 {error && <div className="chat-message assistant-message error-message">{error}</div>}
            </div>

            {/* Input Area */}
            <div className="chat-input-area">
                <textarea
                    value={currentQuestion}
                    onChange={(e) => setCurrentQuestion(e.target.value)}
                    onKeyDown={handleKeyDown}
                    placeholder="Ask about strategies, metrics, or results..."
                    rows={3}
                    disabled={isLoading}
                    aria-label="Ask the LLM guide a question"
                />
                <div className="chat-buttons">
                     <button onClick={handleReset} disabled={isLoading || conversation.length === 0} title="Clear chat history">
                        Reset
                    </button>
                    <button onClick={() => handleAskQuestion()} disabled={isLoading || !currentQuestion.trim()}>
                        {isLoading ? 'Asking...' : 'Ask Guide'}
                    </button>
                </div>
            </div>
        </div>
    );
};

export default LLMChat;
EOF

# --- App Component ---
echo "[INFO] Writing src/App.tsx..."
cat << 'EOF' > src/App.tsx
import React, { useState, useCallback, useMemo } from 'react';
import './App.css'; // Main CSS file
import ControlPanel from './components/ControlPanel';
import ResultsDisplay from './components/ResultsDisplay';
import ChartDisplay from './components/ChartDisplay';
import LLMChat from './components/LLMChat';
import LoadingSpinner from './components/LoadingSpinner';
import { BacktestResult, ApiError } from './types';

function App() {
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [backtestResult, setBacktestResult] = useState<BacktestResult | null>(null);
    const [backtestError, setBacktestError] = useState<ApiError | null>(null);

    // Callback when backtest starts
    const handleBacktestStart = useCallback(() => {
        console.log("Backtest started...");
        setIsLoading(true);
        setBacktestResult(null); // Clear previous results
        setBacktestError(null); // Clear previous errors
    }, []);

    // Callback when backtest completes (successfully or with error)
    const handleBacktestComplete = useCallback((result: BacktestResult | null, error?: ApiError) => {
        console.log("Backtest completed. Error:", error, "Result:", result);
        setIsLoading(false);
        if (error) {
            // Handle errors reported by the API call itself (e.g., network, 4xx, 5xx)
            setBacktestError(error);
            setBacktestResult(null);
        } else if (result) {
             // Handle errors reported *within* the successful API response body (e.g., data fetch fail during run)
             if(result.errorMessage) {
                 setBacktestError({ message: result.errorMessage }); // Treat internal error like an API error
                 setBacktestResult(null); // Don't show potentially incomplete results
             } else {
                 // Success case with valid results
                 setBacktestResult(result);
                 setBacktestError(null);
             }
        } else {
            // Should not happen if error is also null, but handle defensively
             setBacktestError({ message: "Received incomplete or unexpected data from the backtest." });
             setBacktestResult(null);
        }
    }, []);

    // Memoized function to generate context string for the LLM
    const getLLMContext = useCallback((): string => {
        if (!backtestResult || !backtestResult.metrics) return '';

        const { metrics, strategyName, ticker, startDate, endDate } = backtestResult;

        // Format dates nicely for context
        const formattedStartDate = new Date(startDate).toLocaleDateString();
        const formattedEndDate = new Date(endDate).toLocaleDateString();

        // Build the context string
        let context = `Current Backtest Context:
Strategy: ${strategyName}
Ticker: ${ticker}
Period: ${formattedStartDate} - ${formattedEndDate}
--- Key Metrics ---
Initial Capital: $${metrics.initialCapital?.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}
Final Value: $${metrics.finalPortfolioValue?.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}
Total Return: ${metrics.totalReturnPercent?.toFixed(2)}%
Annualized Return: ${metrics.annualizedReturnPercent?.toFixed(2)}%
Sharpe Ratio: ${metrics.sharpeRatio?.toFixed(3)}
Max Drawdown: ${metrics.maxDrawdownPercent?.toFixed(2)}%
Approx Trade Pairs: ${metrics.numberOfTradePairs}
`;
        console.log("Providing LLM context:", context); // Log for debugging
        return context;
    }, [backtestResult]); // Dependency: regenerate context only when backtestResult changes


    return (
        <div className="App">
            <header className="App-header">
                <h1>Stock Trading Strategy Simulator</h1>
                 <p className="disclaimer">
                    <strong>Disclaimer:</strong> For educational/simulation purposes only. Not financial advice. Past performance does not guarantee future results. Simulations ignore real-world costs (commissions, slippage, taxes). Consult a qualified financial advisor before investing.
                </p>
            </header>

            <main className="App-main">
                 {/* Conditionally render loading spinner overlay */}
                 {isLoading && <LoadingSpinner />}

                <ControlPanel
                    onBacktestStart={handleBacktestStart}
                    onBacktestComplete={handleBacktestComplete}
                    isLoading={isLoading}
                />

                 {/* Display Area for Results or Errors */}
                 <div className="results-area">
                    {/* Display error if backtest failed */}
                    {backtestError && !isLoading && (
                        <div className="error-message card">
                            <h2>Backtest Error</h2>
                            <p>{backtestError.message}</p>
                             {/* Optionally show more details if available */}
                             {/* <pre>{JSON.stringify(backtestError.details, null, 2)}</pre> */}
                        </div>
                    )}

                    {/* Display results if backtest succeeded */}
                    {backtestResult && !isLoading && !backtestError && (
                         <>
                            <ResultsDisplay results={backtestResult} />
                            <ChartDisplay results={backtestResult} />
                         </>
                    )}

                     {/* Placeholder when no results or errors yet */}
                    {!isLoading && !backtestResult && !backtestError && (
                        <div className="card placeholder-message">
                            <p>Configure and run a backtest using the controls above.</p>
                        </div>
                    )}
                 </div>

                 {/* LLM Chat Component */}
                 <div className="llm-area">
                    <LLMChat contextProvider={getLLMContext} />
                 </div>

            </main>

            <footer className="App-footer">
                 Created as a Demonstration Project
            </footer>
        </div>
    );
}

export default App;
EOF

# --- CSS Files ---
echo "[INFO] Writing src/App.css..."
cat << 'EOF' > src/App.css
/* --- Global Styles & Layout --- */
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  background-color: #f4f7f9; /* Light grey background */
  color: #333; /* Default text color */
  line-height: 1.6;
}

.App {
  max-width: 1400px; /* Wider max-width */
  margin: 0 auto;
  padding: 20px;
}

/* --- Header --- */
.App-header {
  background: linear-gradient(to right, #3a6ea5, #2a4d75); /* Gradient background */
  padding: 25px 30px;
  color: white;
  text-align: center;
  border-radius: 8px;
  margin-bottom: 30px;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.App-header h1 {
  margin: 0 0 10px 0;
  font-size: 2.2em;
  font-weight: 600;
}

.disclaimer {
  font-size: 0.85em;
  color: #d0e0f0; /* Lighter color for disclaimer */
  margin: 0;
  max-width: 800px;
  margin-left: auto;
  margin-right: auto;
}

/* --- Main Layout --- */
.App-main {
  display: grid;
  grid-template-columns: 1fr; /* Single column mobile first */
  gap: 25px;
}

/* Grid layout for larger screens */
@media (min-width: 1024px) {
  .App-main {
    /* Example: 1/3 for controls+LLM, 2/3 for results+chart */
    grid-template-columns: 1fr 2fr;
     /* Define areas for clarity */
     grid-template-areas:
      "controls results"
      "llm      results";
  }
  .control-panel { grid-area: controls; }
  .llm-area { grid-area: llm; } /* Wrap LLMChat in a div for area assignment */
  .results-area { grid-area: results; display: flex; flex-direction: column; gap: 25px;} /* Allow results/chart to stack */
}

/* --- Card Styling --- */
.card {
  background-color: #fff;
  border-radius: 8px;
  padding: 25px;
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.08);
  border: 1px solid #e0e0e0;
}

.card h2 {
    margin-top: 0;
    margin-bottom: 20px;
    color: #2a4d75; /* Match header theme */
    font-size: 1.4em;
    border-bottom: 1px solid #eee;
    padding-bottom: 10px;
}


/* --- Form Group Styling --- */
.form-group {
  margin-bottom: 18px;
}

.form-group label {
  display: block;
  margin-bottom: 6px;
  font-weight: 600;
  color: #555;
  font-size: 0.95em;
}

.form-group input[type="text"],
.form-group input[type="date"],
.form-group input[type="number"],
.form-group select {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #ccc;
  border-radius: 4px;
  box-sizing: border-box;
  font-size: 1em;
  transition: border-color 0.2s ease;
}

.form-group input:focus,
.form-group select:focus {
    border-color: #3a6ea5; /* Highlight focus */
    outline: none;
    box-shadow: 0 0 0 2px rgba(58, 110, 165, 0.2);
}


.form-group input:disabled,
.form-group select:disabled {
  background-color: #e9ecef;
  cursor: not-allowed;
  opacity: 0.7;
}

.date-group {
  display: grid;
  grid-template-columns: 1fr 1fr; /* Side-by-side dates */
  gap: 15px;
}
/* On smaller screens, stack dates */
@media (max-width: 576px) {
    .date-group { grid-template-columns: 1fr; }
}


.strategy-description {
  font-size: 0.9em;
  color: #666;
  margin-top: 8px;
  margin-bottom: 0;
  padding-left: 5px;
  border-left: 2px solid #eee;
}

/* --- Buttons --- */
button.run-button, .llm-chat button {
  background-color: #3a6ea5; /* Primary color */
  color: white;
  padding: 10px 18px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1em;
  font-weight: 500;
  transition: background-color 0.2s ease, box-shadow 0.2s ease;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

button.run-button:hover:not(:disabled), .llm-chat button:hover:not(:disabled) {
  background-color: #2a4d75; /* Darker shade on hover */
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

button.run-button:disabled, .llm-chat button:disabled {
  background-color: #b0c4de; /* Lighter blue-grey when disabled */
  cursor: not-allowed;
  box-shadow: none;
}
.llm-chat button[title="Clear chat history"] {
    background-color: #6c757d; /* Grey for reset */
}
.llm-chat button[title="Clear chat history"]:hover:not(:disabled) {
     background-color: #5a6268;
}


/* --- Error Message Styling --- */
.error-message {
  color: #842029; /* Dark red text */
  background-color: #f8d7da; /* Light red background */
  border: 1px solid #f5c2c7; /* Reddish border */
  padding: 12px 18px;
  border-radius: 4px;
  margin-top: 15px;
  font-size: 0.95em;
}
.error-message h2 { /* Specific styling if error has a heading */
  margin-top: 0;
  margin-bottom: 10px;
  color: #721c24; /* Even darker red for heading */
  font-size: 1.2em;
}

.validation-error {
    color: #dc3545;
    font-size: 0.85em;
    margin-top: 4px;
    display: block; /* Make it block for spacing */
}
.validation-error-inline { /* For errors next to inputs */
    color: #dc3545;
    font-size: 0.85em;
    margin-left: 10px;
}


/* --- Placeholder Message --- */
.placeholder-message {
    text-align: center;
    color: #666;
    padding: 40px 20px;
    font-style: italic;
}


/* --- Footer --- */
.App-footer {
  margin-top: 40px;
  text-align: center;
  font-size: 0.9em;
  color: #777;
  padding-top: 20px;
  border-top: 1px solid #eee;
}
EOF

echo "[INFO] Writing src/components/LoadingSpinner.css..."
cat << 'EOF' > src/components/LoadingSpinner.css
.loading-spinner-overlay {
  position: fixed; /* Cover the whole screen */
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(255, 255, 255, 0.8); /* Semi-transparent white */
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000; /* Ensure it's on top */
}

.loading-spinner {
  border: 5px solid #f3f3f3; /* Light grey */
  border-top: 5px solid #3a6ea5; /* Primary color */
  border-radius: 50%;
  width: 50px;
  height: 50px;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
EOF

echo "[INFO] Writing src/components/ResultsDisplay.css..."
cat << 'EOF' > src/components/ResultsDisplay.css
.results-display .results-summary {
    font-size: 1.05em;
    color: #555;
    margin-bottom: 20px;
    padding-bottom: 15px;
    border-bottom: 1px solid #eee;
}

.results-display .metrics-list {
    list-style: none;
    padding: 0;
    margin: 0;
}

.results-display .metrics-list li {
    display: flex;
    justify-content: space-between;
    padding: 8px 0;
    border-bottom: 1px solid #f0f0f0;
    font-size: 1em;
}
.results-display .metrics-list li:last-child {
    border-bottom: none;
}

.results-display .metrics-list strong {
    color: #333;
    margin-right: 15px;
    font-weight: 500; /* Slightly less bold */
}

.results-display .metrics-list span {
    font-weight: 600; /* Make values stand out */
    text-align: right;
}

/* Color coding for returns and drawdown */
.results-display .metrics-list .positive span {
    color: #28a745; /* Green */
}
.results-display .metrics-list .negative span {
    color: #dc3545; /* Red */
}
.results-display .metrics-list .warning span { /* For moderately negative drawdown */
    color: #ffc107; /* Amber */
}

.results-display .results-disclaimer {
    font-size: 0.85em;
    color: #6c757d; /* Muted grey */
    margin-top: 20px;
    padding-top: 15px;
    border-top: 1px dashed #eee;
}
EOF

echo "[INFO] Writing src/components/LLMChat.css..."
cat << 'EOF' > src/components/LLMChat.css
.llm-chat .guide-description {
    font-size: 0.9em;
    color: #666;
    margin-bottom: 15px;
}

.llm-chat .chat-history {
    height: 350px; /* Adjust height as needed */
    overflow-y: auto;
    border: 1px solid #e0e0e0;
    padding: 15px;
    margin-bottom: 15px;
    background-color: #f9fafb; /* Very light grey */
    border-radius: 6px;
    line-height: 1.5;
}

.llm-chat .chat-message {
    margin-bottom: 12px;
    max-width: 90%; /* Prevent messages from spanning full width */
    clear: both; /* Ensure messages don't overlap floats */
    word-wrap: break-word; /* Break long words */
}
.llm-chat .chat-message p {
    margin: 0 0 5px 0; /* Space between paragraphs within a message */
}
.llm-chat .chat-message p:last-child {
    margin-bottom: 0;
}


.llm-chat .user-message {
    text-align: right;
    float: right; /* Align user messages to the right */
}
.llm-chat .user-message p {
    background-color: #dbeafe; /* Light blue background for user */
    color: #1e40af; /* Darker blue text */
    padding: 8px 12px;
    border-radius: 12px 12px 0 12px; /* Rounded corners */
    display: inline-block; /* Fit content */
    text-align: left; /* Align text left within bubble */
}

.llm-chat .assistant-message {
    text-align: left;
     float: left; /* Align assistant messages to the left */
}
.llm-chat .assistant-message p {
    background-color: #e5e7eb; /* Light grey background for assistant */
    color: #374151; /* Dark grey text */
    padding: 8px 12px;
    border-radius: 12px 12px 12px 0; /* Rounded corners */
    display: inline-block; /* Fit content */
}

/* Loading indicator */
.loading-dots span {
    display: inline-block;
    width: 6px;
    height: 6px;
    background-color: currentColor; /* Inherit color from parent (.assistant-message p) */
    border-radius: 50%;
    margin: 0 2px;
    animation: bounce 1.4s infinite ease-in-out both;
}
.loading-dots span:nth-child(1) { animation-delay: -0.32s; }
.loading-dots span:nth-child(2) { animation-delay: -0.16s; }

@keyframes bounce {
  0%, 80%, 100% { transform: scale(0); }
  40% { transform: scale(1.0); }
}


.llm-chat .chat-input-area {
    display: flex;
    flex-direction: column; /* Stack textarea and buttons */
    gap: 10px;
}

.llm-chat textarea {
    width: 100%;
    box-sizing: border-box;
    min-height: 70px; /* Slightly taller textarea */
    padding: 10px 12px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 1em;
    font-family: inherit; /* Use same font as body */
    resize: vertical; /* Allow vertical resize */
     transition: border-color 0.2s ease;
}
.llm-chat textarea:focus {
     border-color: #3a6ea5;
     outline: none;
     box-shadow: 0 0 0 2px rgba(58, 110, 165, 0.2);
}
.llm-chat textarea:disabled {
     background-color: #e9ecef;
     cursor: not-allowed;
}


.llm-chat .chat-buttons {
    display: flex;
    justify-content: flex-end; /* Align buttons to the right */
    gap: 10px;
}

.llm-chat .error-message { /* Reuse error message style */
    font-size: 0.9em;
    padding: 8px 12px !important; /* Override padding if needed */
}

EOF

# --- Add common frontend packages ---
echo "[INFO] Adding common frontend packages (axios, chart.js, react-chartjs-2, date-fns, chartjs-adapter-date-fns)..."
npm install axios chart.js react-chartjs-2 date-fns chartjs-adapter-date-fns
# OR use yarn: yarn add axios chart.js react-chartjs-2 date-fns chartjs-adapter-date-fns
if [ $? -ne 0 ]; then echo "[WARNING] npm install failed. Check internet connection and npm setup."; fi

# --- Create .env files for API URL ---
echo "[INFO] Writing .env files for frontend API configuration..."
cat << 'EOF' > .env.development
# This file is for local development settings
# Used when running `npm start` or `yarn start`
REACT_APP_API_URL=https://localhost:7123/api

# --- IMPORTANT ---
# Make sure the port number (7123) matches the HTTPS port your .NET backend runs on locally.
# Check your backend's Properties/launchSettings.json file.
EOF

cat << 'EOF' > .env.production
# This file is for production build settings
# Used when running `npm run build` or `yarn build`
# Replace with the actual URL where your backend API will be hosted
REACT_APP_API_URL=https://your-deployed-api.example.com/api
EOF

# Frontend .gitignore is usually well-configured by create-react-app

# --- Return to root directory ---
cd ..
echo "[INFO] Finished frontend setup."

# =====================================================
#                  FINAL MESSAGES
# =====================================================
echo ""
echo "-----------------------------------------------------"
echo "--- Project Structure & Code Generation Complete! ---"
echo "-----------------------------------------------------"
echo "Project created in directory: '$ROOT_DIR'"
echo ""
echo "*** CRITICAL NEXT STEPS ***"
echo "1. SECURE API KEYS: Navigate to '$ROOT_DIR/$BACKEND_DIR' and replace the placeholder API key in 'appsettings.json' with a secure method:"
echo "   - .NET User Secrets (Recommended for Dev): dotnet user-secrets set \"OpenAI:ApiKey\" \"YOUR_REAL_KEY\""
echo "   - Environment Variables (Good for Dev/Prod)"
echo "   - Azure Key Vault (Recommended for Prod)"
echo "2. Verify Ports: Check '$ROOT_DIR/$BACKEND_DIR/Properties/launchSettings.json' for the backend's HTTPS port. Ensure it matches the port in '$ROOT_DIR/$FRONTEND_DIR/.env.development' (default assumed 7123)."
echo "3. Install Node Modules: Navigate to '$ROOT_DIR/$FRONTEND_DIR' and run 'npm install' or 'yarn install' if any packages failed during script execution."
echo ""
echo "--- To Run the Application ---"
echo "1. Backend: Navigate to '$ROOT_DIR/$BACKEND_DIR' and run 'dotnet run'."
echo "2. Frontend: Navigate to '$ROOT_DIR/$FRONTEND_DIR' in a SEPARATE terminal and run 'npm start' or 'yarn start'."
echo "3. Open your browser to the URL provided by the React development server (usually http://localhost:3000)."
echo ""
echo "--- Remember ---"
echo "- This is template code. Review, test, and enhance error handling, security, and features."
echo "- The YahooFinanceApi library's reliability can vary; consider alternatives for production."
echo "- Consult financial professionals before making any trading decisions."
echo "-----------------------------------------------------"
