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
    public string? Endpoint { get; internal set; }
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
