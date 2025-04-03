import axios, { AxiosError } from 'axios';
import {
    BacktestRequest,
    BacktestResult,
    StrategyInfo,
    LLMRequest,
    LLMResponse,
    ApiError,
    ChatMessage // Import ChatMessage if using history
} from '../types';

// Configure base URL for the API
// Use environment variables set by CRA build process (.env files)
const API_BASE_URL = process.env.REACT_APP_API_URL || '/api'; // Default for local dev
console.log(`API Base URL configured to: ${API_BASE_URL}`); // Log for debugging

const apiClient = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json',
        'X-Github-Token': process.env.REACT_APP_GITHUB_TOKEN || '[NO TOKEN]', 
    },
    // Optional: Timeout configuration
    // timeout: 10000, // 10 seconds timeout
});

// --- Helper for Error Handling ---
// Parses Axios errors into a more consistent ApiError structure
const handleApiError = (error: unknown): ApiError => {
    if (axios.isAxiosError(error)) {
        const axiosError = error as AxiosError<any>; // Use 'any' for potential non-standard error shapes
        console.error('API Error:', axiosError.response?.status, axiosError.response?.data, axiosError.config?.url);

        let message = 'An API error occurred.';
        // Try to extract meaningful error message from response body
        // ASP.NET validation errors often in `errors` or `title`
        if (axiosError.response?.data) {
            if (typeof axiosError.response.data === 'string') {
                message = axiosError.response.data;
            } else if (axiosError.response.data.message) {
                message = axiosError.response.data.message;
            } else if (axiosError.response.data.title) { // ASP.NET ProblemDetails title
                 message = axiosError.response.data.title;
                 // Include validation errors if present
                if (axiosError.response.data.errors) {
                     const validationErrors = Object.entries(axiosError.response.data.errors)
                         .map(([field, errors]) => `${field}: ${(errors as string[]).join(', ')}`)
                         .join('; ');
                     if(validationErrors) message += ` (${validationErrors})`;
                }
            }
        } else if (axiosError.message) { // Fallback to Axios error message
             message = axiosError.message;
        }

        return {
            message: message,
            statusCode: axiosError.response?.status,
            details: axiosError.response?.data // Include full details for potential debugging
        };
    } else {
        // Handle non-Axios errors (e.g., network issues before request is sent, code errors)
        console.error('Unexpected Error in API call:', error);
        return {
            message: error instanceof Error ? error.message : 'An unexpected error occurred',
        };
    }
};


// --- API Functions ---

/**
 * Fetches the list of available trading strategies from the backend.
 */
export const getStrategies = async (): Promise<StrategyInfo[]> => {
    try {
        console.debug('API Call: GET /data/strategies');
        const response = await apiClient.get<StrategyInfo[]>('/data/strategies');
        console.debug('API Response: GET /data/strategies - Success', response.data);
        return response.data;
    } catch (error) {
        console.error('API Error: GET /data/strategies');
        throw handleApiError(error); // Throw consistent error object
    }
};

/**
 * Runs a backtest simulation via the backend API.
 */
export const runBacktest = async (request: BacktestRequest): Promise<BacktestResult> => {
    console.debug('API Call: POST /backtest/run', request);
    try {
        const response = await apiClient.post<BacktestResult>('/backtest/run', request);
        console.debug('API Response: POST /backtest/run - Success'); // Avoid logging full result data unless necessary
        return response.data;
    } catch (error) {
        console.error('API Error: POST /backtest/run');
        throw handleApiError(error);
    }
};


/**
 * Sends a question to the LLM guide via the backend API.
 */
export const askLLM = async (request: LLMRequest): Promise<LLMResponse> => {
    console.debug('API Call: POST /llm/ask', { questionLength: request.question.length, contextProvided: !!request.context }); // Log less sensitive info
    try {
        const response = await apiClient.post<LLMResponse>('/llm/ask', request);
        console.debug('API Response: POST /llm/ask - Success');
        return response.data;
    } catch (error) {
        console.error('API Error: POST /llm/ask');
        throw handleApiError(error);
    }
};
