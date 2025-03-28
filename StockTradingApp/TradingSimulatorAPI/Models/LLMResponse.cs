namespace TradingSimulatorAPI.Models;

public class LLMResponse
{
    public string Answer { get; set; } = string.Empty;
    public List<ChatMessage>? UpdatedConversationHistory { get; set; } // Optional: Return updated history
    public string? Error { get; set; } // In case LLM call fails
}
