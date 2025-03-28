import React, { useState, useCallback, useMemo } from 'react';
import './App.css'; // Main CSS file
import ControlPanel from './components/ControlPanel';
import ResultsDisplay from './components/ResultsDisplay';
import ChartDisplay from './components/ChartDisplay';
import LLMChat from './components/LLMChat';
import LoadingSpinner from './components/LoadingSpinner';
import { BacktestResult, ApiError } from './types';

function App() {
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [backtestResult, setBacktestResult] = useState<BacktestResult | null>(null);
    const [backtestError, setBacktestError] = useState<ApiError | null>(null);

    // Callback when backtest starts
    const handleBacktestStart = useCallback(() => {
        console.log("Backtest started...");
        setIsLoading(true);
        setBacktestResult(null); // Clear previous results
        setBacktestError(null); // Clear previous errors
    }, []);

    // Callback when backtest completes (successfully or with error)
    const handleBacktestComplete = useCallback((result: BacktestResult | null, error?: ApiError) => {
        console.log("Backtest completed. Error:", error, "Result:", result);
        setIsLoading(false);
        if (error) {
            // Handle errors reported by the API call itself (e.g., network, 4xx, 5xx)
            setBacktestError(error);
            setBacktestResult(null);
        } else if (result) {
             // Handle errors reported *within* the successful API response body (e.g., data fetch fail during run)
             if(result.errorMessage) {
                 setBacktestError({ message: result.errorMessage }); // Treat internal error like an API error
                 setBacktestResult(null); // Don't show potentially incomplete results
             } else {
                 // Success case with valid results
                 setBacktestResult(result);
                 setBacktestError(null);
             }
        } else {
            // Should not happen if error is also null, but handle defensively
             setBacktestError({ message: "Received incomplete or unexpected data from the backtest." });
             setBacktestResult(null);
        }
    }, []);

    // Memoized function to generate context string for the LLM
    const getLLMContext = useCallback((): string => {
        if (!backtestResult || !backtestResult.metrics) return '';

        const { metrics, strategyName, ticker, startDate, endDate } = backtestResult;

        // Format dates nicely for context
        const formattedStartDate = new Date(startDate).toLocaleDateString();
        const formattedEndDate = new Date(endDate).toLocaleDateString();

        // Build the context string
        let context = `Current Backtest Context:
Strategy: ${strategyName}
Ticker: ${ticker}
Period: ${formattedStartDate} - ${formattedEndDate}
--- Key Metrics ---
Initial Capital: $${metrics.initialCapital?.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}
Final Value: $${metrics.finalPortfolioValue?.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}
Total Return: ${metrics.totalReturnPercent?.toFixed(2)}%
Annualized Return: ${metrics.annualizedReturnPercent?.toFixed(2)}%
Sharpe Ratio: ${metrics.sharpeRatio?.toFixed(3)}
Max Drawdown: ${metrics.maxDrawdownPercent?.toFixed(2)}%
Approx Trade Pairs: ${metrics.numberOfTradePairs}
`;
        console.log("Providing LLM context:", context); // Log for debugging
        return context;
    }, [backtestResult]); // Dependency: regenerate context only when backtestResult changes


    return (
        <div className="App">
            <header className="App-header">
                <h1>Stock Trading Strategy Simulator</h1>
                 <p className="disclaimer">
                    <strong>Disclaimer:</strong> For educational/simulation purposes only. Not financial advice. Past performance does not guarantee future results. Simulations ignore real-world costs (commissions, slippage, taxes). Consult a qualified financial advisor before investing.
                </p>
            </header>

            <main className="App-main">
                 {/* Conditionally render loading spinner overlay */}
                 {isLoading && <LoadingSpinner />}

                <ControlPanel
                    onBacktestStart={handleBacktestStart}
                    onBacktestComplete={handleBacktestComplete}
                    isLoading={isLoading}
                />

                 {/* Display Area for Results or Errors */}
                 <div className="results-area">
                    {/* Display error if backtest failed */}
                    {backtestError && !isLoading && (
                        <div className="error-message card">
                            <h2>Backtest Error</h2>
                            <p>{backtestError.message}</p>
                             {/* Optionally show more details if available */}
                             {/* <pre>{JSON.stringify(backtestError.details, null, 2)}</pre> */}
                        </div>
                    )}

                    {/* Display results if backtest succeeded */}
                    {backtestResult && !isLoading && !backtestError && (
                         <>
                            <ResultsDisplay results={backtestResult} />
                            <ChartDisplay results={backtestResult} />
                         </>
                    )}

                     {/* Placeholder when no results or errors yet */}
                    {!isLoading && !backtestResult && !backtestError && (
                        <div className="card placeholder-message">
                            <p>Configure and run a backtest using the controls above.</p>
                        </div>
                    )}
                 </div>

                 {/* LLM Chat Component */}
                 <div className="llm-area">
                    <LLMChat contextProvider={getLLMContext} />
                 </div>

            </main>

            <footer className="App-footer">
                 Created as a Demonstration Project
            </footer>
        </div>
    );
}

export default App;
