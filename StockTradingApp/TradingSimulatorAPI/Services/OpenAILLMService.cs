using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using TradingSimulatorAPI.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;
using OpenAI;
using OpenAI.Chat;
using ChatMessage = OpenAI.Chat.ChatMessage;

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
        var messages = new List<OpenAI.Chat.ChatMessage>();

        // 1. Add the System Prompt
        messages.Add(new SystemChatMessage(SystemPrompt));

        // 2. Add provided context
        if (!string.IsNullOrWhiteSpace(request.Context))
        {
            messages.Add(new SystemChatMessage($"Context for the user's question:\n{request.Context}"));
        }

        // 3. Add Conversation History (if provided)
        if (request.ConversationHistory != null && request.ConversationHistory.Any())
        {
            foreach (var message in request.ConversationHistory)
            {
                 if (message.Role.Equals("user", StringComparison.OrdinalIgnoreCase))
                 {
                      messages.Add(new UserChatMessage(message.Content));
                 }
                 else if (message.Role.Equals("assistant", StringComparison.OrdinalIgnoreCase))
                 {
                      messages.Add(new AssistantChatMessage(message.Content));
                 }
                 // Ignore system messages from history as we add our own canonical one
            }
             _logger.LogDebug("Added {HistoryCount} messages from provided history.", request.ConversationHistory.Count);
        }

        // 4. Add the Current User Question
        messages.Add(new UserChatMessage(request.Question));


        // 5. Prepare OpenAI Request Options
        var chatCompletionsOptions = new ChatCompletionOptions()
        {
            Temperature = 0.5f, // Adjust for creativity vs. factuality (0.0 to 1.0)
            MaxOutputTokenCount = 1000, // Limit response length
            //NucleusSamplingFactor = 0.95f, // Top-p sampling - Removed as it's not directly available, can be implemented with custom logic
            FrequencyPenalty = 0,
            PresencePenalty = 0,
        };

        try
        {
            _logger.LogDebug("Sending request to OpenAI model {Model} with {MessageCount} messages.", _settings.Model, messages.Count);
            _logger.LogDebug("Sending request to OpenAI model {Model} with {MessageCount} messages.", _settings.Model, messages.Count);
            var openAiResponse = await _client.GetChatClient(_settings.Model)
            .CompleteChatAsync(messages, chatCompletionsOptions);

            if (openAiResponse != null && openAiResponse.Value != null && openAiResponse.Value.Content.Count > 0)
            {
                var choice = openAiResponse.Value;
                response.Answer = string.Join("", choice.Content);
                _logger.LogInformation("Received successful response from OpenAI. Finish Reason: {FinishReason}", choice.FinishReason);

                // Update conversation history for the response
                response.UpdatedConversationHistory = request.ConversationHistory ?? new List<TradingSimulatorAPI.Models.ChatMessage>();
                // Add the user question
                response.UpdatedConversationHistory.Add(new TradingSimulatorAPI.Models.ChatMessage { Role = "user", Content = request.Question });
                response.UpdatedConversationHistory.Add(new TradingSimulatorAPI.Models.ChatMessage { Role = "assistant", Content = response.Answer });

                // Optional: Trim history if it gets too long
                response.UpdatedConversationHistory = TrimHistory(response.UpdatedConversationHistory);
            }
            {
                _logger.LogWarning("OpenAI response was empty or contained no choices.");
                response.Error = "LLM returned an empty response.";
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unexpected error occurred while interacting with OpenAI.");
            response.Error = $"An unexpected error occurred: {ex.Message}";
        }

        return response;
    }

     // Simple history trimming (keep system + last N user/assistant pairs)
    private List<TradingSimulatorAPI.Models.ChatMessage> TrimHistory(List<TradingSimulatorAPI.Models.ChatMessage> history, int maxMessages = 10) // Keep last 5 pairs (10 messages) + context
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
