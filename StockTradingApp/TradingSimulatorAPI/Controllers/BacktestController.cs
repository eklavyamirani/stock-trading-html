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
