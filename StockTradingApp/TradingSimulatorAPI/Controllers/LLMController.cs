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
