// Shared types between frontend and backend (match C# DTOs)

// Corresponds to Models/PerformanceMetrics.cs
export interface PerformanceMetrics {
  initialCapital: number;
  finalPortfolioValue: number;
  totalReturnPercent: number;
  annualizedReturnPercent: number;
  sharpeRatio: number;
  maxDrawdownPercent: number;
  numberOfTradePairs: number;
}

// Corresponds to Models/TradeLogEntry.cs
export interface TradeLogEntry {
  date: string; // ISO date string
  action: 'BUY' | 'SELL';
  price: number;
  shares: number;
  cost?: number; // Present for BUY
  proceeds?: number; // Present for SELL
  commission?: number; // Optional
}

// Corresponds to Models/ChartDataPoint.cs
export interface ChartDataPoint {
    date: string; // ISO date string (e.g., "2023-10-27T00:00:00Z") or Date object parsable string
    value: number;
}

// Corresponds to Models/BacktestResult.cs
export interface BacktestResult {
  strategyName: string;
  ticker: string;
  startDate: string; // ISO date string
  endDate: string; // ISO date string
  metrics: PerformanceMetrics | null;
  portfolioValueHistory: ChartDataPoint[];
  benchmarkValueHistory: ChartDataPoint[]; // Normalized benchmark price
  tradeLog: TradeLogEntry[];
  errorMessage?: string; // If backtest failed on the backend
  // signalsData?: any[]; // Optional: Raw data with signals for advanced plotting
}

// Corresponds to Models/BacktestRequest.cs (for sending)
export interface BacktestRequest {
  ticker: string;
  startDate: string; // Format: YYYY-MM-DD
  endDate: string; // Format: YYYY-MM-DD
  strategyName: string;
  initialCapital: number;
  parameters?: Record<string, any>; // Strategy-specific parameters { key: value }
}

// Corresponds to Models/StrategyInfo.cs
export interface StrategyInfo {
    name: string; // Internal name used in API calls
    displayName: string; // User-friendly name
    description: string;
    // Optional: Define parameter structure if needed on frontend
    parameters?: Record<string, { type: string; description: string; defaultValue?: any }>;
}

// For LLM Interaction (Matches C# Models)
export interface ChatMessage {
    role: 'user' | 'assistant' | 'system'; // Align with backend roles
    content: string;
}
export interface LLMRequest {
    question: string;
    context?: string;
    conversationHistory?: ChatMessage[];
}
export interface LLMResponse {
    answer: string;
    updatedConversationHistory?: ChatMessage[];
    error?: string; // Handle potential errors from LLM service
}

// General API Error structure (from api.ts helper)
export interface ApiError {
    message: string;
    statusCode?: number;
    details?: any; // Can contain validation errors etc.
}
