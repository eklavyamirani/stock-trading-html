using TradingSimulatorAPI.Models;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;

namespace TradingSimulatorAPI.Services;

// WARNING: Reliance on unofficial APIs like Yahoo Finance can be unstable.
// Consider paid, reliable data providers for serious applications.
public class YahooFinanceStockDataService : IStockDataService
{
    private readonly ILogger<YahooFinanceStockDataService> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private static readonly SemaphoreSlim _throttleSemaphore = new SemaphoreSlim(1, 1);
    private static DateTime _lastRequestTime = DateTime.MinValue;
    private const int _minimumDelayMs = 2000; // Wait at least 2 seconds between requests
    private const int _maxRetries = 3;

    public YahooFinanceStockDataService(ILogger<YahooFinanceStockDataService> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    public async Task<List<HistoricalDataPoint>?> GetHistoricalDataAsync(string ticker, DateTime startDate, DateTime endDate)
    {
        _logger.LogInformation("Fetching historical data for {0} from {1} to {2}", ticker, startDate, endDate);

        // Set up retry logic
        int retryCount = 0;
        int baseDelayMs = 3000; // Start with 3 second delay

        while (true)
        {
            try
            {
                // Throttle requests to avoid rate limits
                await ThrottleRequests();
                
                // Using Yahoo Finance Chart API
                var httpClient = _httpClientFactory.CreateClient();
                
                // Add browser-like headers to reduce chance of being blocked
                httpClient.DefaultRequestHeaders.Clear();
                httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36");
                httpClient.DefaultRequestHeaders.Add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8");
                httpClient.DefaultRequestHeaders.Add("Accept-Language", "en-US,en;q=0.9");
                httpClient.DefaultRequestHeaders.Add("Connection", "keep-alive");
                httpClient.DefaultRequestHeaders.Add("Cache-Control", "max-age=0");
                
                // Convert dates to Unix timestamps (seconds since epoch)
                long startTimestamp = new DateTimeOffset(startDate).ToUnixTimeSeconds();
                long endTimestamp = new DateTimeOffset(endDate).ToUnixTimeSeconds();
                
                // Build the chart API URL - this uses v8 of Yahoo's chart API
                string url = $"https://query1.finance.yahoo.com/v8/finance/chart/{Uri.EscapeDataString(ticker)}?period1={startTimestamp}&period2={endTimestamp}&interval=1d";
                
                _logger.LogDebug("Requesting URL: {0}", url);
                
                // Make the HTTP request
                var response = await httpClient.GetAsync(url);
                
                // Check for rate limiting
                if (response.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
                {
                    if (retryCount >= _maxRetries)
                    {
                        _logger.LogError("Rate limit exceeded for {0} after {1} retries.", ticker, _maxRetries);
                        throw new HttpRequestException($"Failed to fetch data for {ticker}: Rate limit exceeded even after retrying.");
                    }
                    
                    int delayMs = baseDelayMs * (int)Math.Pow(2, retryCount); // Exponential backoff
                    _logger.LogWarning("Rate limit hit for {0}. Retrying in {1}ms (attempt {2}/{3})...", ticker, delayMs, retryCount + 1, _maxRetries);
                    await Task.Delay(delayMs);
                    retryCount++;
                    continue;
                }
                
                response.EnsureSuccessStatusCode();
                
                // Parse the JSON response
                var jsonResponse = await response.Content.ReadFromJsonAsync<JsonNode>();
                
                if (jsonResponse == null || jsonResponse["chart"] == null || jsonResponse["chart"]!["result"] == null || jsonResponse["chart"]!["result"]!.AsArray().Count == 0)
                {
                    _logger.LogWarning("No chart data found for {0} in the specified range.", ticker);
                    return null;
                }
                
                var result = jsonResponse["chart"]!["result"]![0];
                var timestamp = result?["timestamp"]?.AsArray();
                var quote = result?["indicators"]?["quote"]?[0];
                
                if (timestamp == null || quote == null)
                {
                    _logger.LogWarning("Missing required data in response for {0}.", ticker);
                    return null;
                }
                
                // Extract the data arrays
                var opens = quote["open"]?.AsArray();
                var highs = quote["high"]?.AsArray();
                var lows = quote["low"]?.AsArray();
                var closes = quote["close"]?.AsArray();
                var volumes = quote["volume"]?.AsArray();
                
                // Get adjusted close from adjclose if available
                var adjclose = result?["indicators"]?["adjclose"]?[0]?["adjclose"]?.AsArray();
                
                if (opens == null || highs == null || lows == null || closes == null || volumes == null)
                {
                    _logger.LogWarning("Missing price data in response for {0}.", ticker);
                    return null;
                }
                
                var dataPoints = new List<HistoricalDataPoint>();
                
                // Build historical data points from the arrays
                for (int i = 0; i < timestamp.Count; i++)
                {
                    // Skip any data point where any of the OHLC values are null or the index is out of range
                    if (i >= opens.Count || i >= highs.Count || i >= lows.Count || i >= closes.Count || i >= volumes.Count ||
                        timestamp[i] == null || opens[i] == null || highs[i] == null || lows[i] == null || closes[i] == null || volumes[i] == null)
                    {
                        continue;
                    }
                    
                    // Safely get values with null checks
                    long? unixTime = timestamp[i]?.GetValue<long>();
                    double? openPrice = opens[i]?.GetValue<double>();
                    double? highPrice = highs[i]?.GetValue<double>();
                    double? lowPrice = lows[i]?.GetValue<double>();
                    double? closePrice = closes[i]?.GetValue<double>();
                    long? volume = volumes[i]?.GetValue<long>();
                    
                    // Skip if any value is missing
                    if (!unixTime.HasValue || !openPrice.HasValue || !highPrice.HasValue || !lowPrice.HasValue || !closePrice.HasValue || !volume.HasValue)
                    {
                        continue;
                    }
                    
                    // Convert timestamp to DateTime
                    DateTimeOffset dateTimeOffset = DateTimeOffset.FromUnixTimeSeconds(unixTime.Value);
                    
                    var dataPoint = new HistoricalDataPoint
                    {
                        Date = dateTimeOffset.DateTime.Date,
                        Open = (decimal)openPrice.Value,
                        High = (decimal)highPrice.Value,
                        Low = (decimal)lowPrice.Value,
                        Close = (decimal)closePrice.Value,
                        Volume = volume.Value
                    };
                    
                    // Get adjusted close if available
                    double? adjClosePrice = null;
                    if (adjclose != null && i < adjclose.Count && adjclose[i] != null)
                    {
                        adjClosePrice = adjclose[i]?.GetValue<double>();
                    }
                    
                    // Use adjusted close if available, otherwise use regular close
                    dataPoint.AdjClose = adjClosePrice.HasValue ? (decimal)adjClosePrice.Value : dataPoint.Close;
                    
                    dataPoints.Add(dataPoint);
                }
                
                // Sort by date (should already be in order, but just to be sure)
                dataPoints = dataPoints.OrderBy(dp => dp.Date).ToList();
    
                _logger.LogInformation("Successfully fetched {0} data points for {1}", dataPoints.Count, ticker);
                return dataPoints;
            }
            catch (HttpRequestException ex) when (retryCount < _maxRetries && 
                                                (ex.Message.Contains("429") || ex.Message.Contains("Too Many Requests")))
            {
                int delayMs = baseDelayMs * (int)Math.Pow(2, retryCount); // Exponential backoff
                _logger.LogWarning("HTTP error for {0}: {1}. Retrying in {2}ms (attempt {3}/{4})...", 
                    ticker, ex.Message, delayMs, retryCount + 1, _maxRetries);
                await Task.Delay(delayMs);
                retryCount++;
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "HTTP request failed while fetching data for {0}.", ticker);
                throw;
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "JSON parsing error while processing data for {0}.", ticker);
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An unexpected error occurred while fetching or processing data for {0}.", ticker);
                return null;
            }
        }
    }

    /// <summary>
    /// Throttles API requests to avoid hitting rate limits
    /// </summary>
    private static async Task ThrottleRequests()
    {
        await _throttleSemaphore.WaitAsync();
        try
        {
            // Calculate time since last request
            var timeSinceLastRequest = DateTime.Now - _lastRequestTime;
            
            // If we've made a request recently, wait until the minimum delay has passed
            if (timeSinceLastRequest < TimeSpan.FromMilliseconds(_minimumDelayMs))
            {
                int delayMs = _minimumDelayMs - (int)timeSinceLastRequest.TotalMilliseconds;
                await Task.Delay(delayMs);
            }
            
            // Update last request time
            _lastRequestTime = DateTime.Now;
        }
        finally
        {
            _throttleSemaphore.Release();
        }
    }
}
