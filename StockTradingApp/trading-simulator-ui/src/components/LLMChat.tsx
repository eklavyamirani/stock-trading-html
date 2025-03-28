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
