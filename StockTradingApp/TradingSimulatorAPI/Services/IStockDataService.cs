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
