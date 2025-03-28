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
