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
