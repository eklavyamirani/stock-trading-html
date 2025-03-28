import React, { useState, useEffect, useCallback, ChangeEvent } from 'react';
import { BacktestRequest, StrategyInfo, BacktestResult, ApiError } from '../types';
import { getStrategies, runBacktest } from '../services/api';

interface ControlPanelProps {
    onBacktestStart: () => void;
    onBacktestComplete: (results: BacktestResult | null, error?: ApiError) => void;
    isLoading: boolean; // To disable inputs while loading
}

const ControlPanel: React.FC<ControlPanelProps> = ({ onBacktestStart, onBacktestComplete, isLoading }) => {
    // --- State ---
    const [ticker, setTicker] = useState<string>('^GSPC'); // Default to S&P 500
    const [startDate, setStartDate] = useState<string>('2020-01-01'); // Default start
    const [endDate, setEndDate] = useState<string>(() => new Date().toISOString().split('T')[0]); // Default end (today)
    const [initialCapital, setInitialCapital] = useState<number>(100000);
    const [availableStrategies, setAvailableStrategies] = useState<StrategyInfo[]>([]);
    const [selectedStrategy, setSelectedStrategy] = useState<string>('');
    const [strategyDescription, setStrategyDescription] = useState<string>('');
    const [fetchStrategiesError, setFetchStrategiesError] = useState<string>('');
    const [validationError, setValidationError] = useState<string>('');

    // --- Effects ---

    // Fetch strategies on component mount
    useEffect(() => {
        let isMounted = true; // Prevent state update on unmounted component
        const fetchStrategies = async () => {
            setFetchStrategiesError('');
            try {
                const strategies = await getStrategies();
                if (isMounted) {
                    if (strategies && strategies.length > 0) {
                        setAvailableStrategies(strategies);
                        // Set default selected strategy only if not already set or invalid
                        if (!selectedStrategy || !strategies.some(s => s.name === selectedStrategy)) {
                            setSelectedStrategy(strategies[0].name);
                        }
                    } else {
                        setFetchStrategiesError('No strategies returned from API.');
                    }
                }
            } catch (error: any) {
                console.error("Failed to fetch strategies:", error);
                if (isMounted) {
                    setFetchStrategiesError(`Failed to load strategies: ${error.message || 'Unknown error'}`);
                }
            }
        };
        fetchStrategies();
        return () => { isMounted = false; }; // Cleanup function
    }, []); // Empty dependency array means run once on mount

    // Update strategy description when selectedStrategy or availableStrategies changes
    useEffect(() => {
        const currentStrategy = availableStrategies.find(s => s.name === selectedStrategy);
        setStrategyDescription(currentStrategy?.description || '');
    }, [selectedStrategy, availableStrategies]);

    // --- Event Handlers ---

    const handleInputChange = (setter: React.Dispatch<React.SetStateAction<string | number>>) =>
        (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        setter(e.target.value);
        setValidationError(''); // Clear validation error on input change
    };

     const handleCapitalChange = (e: ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        // Allow empty input or positive numbers
        if (value === '' || /^[0-9]*\.?[0-9]*$/.test(value)) {
            setInitialCapital(value === '' ? 0 : parseFloat(value)); // Store as number
             setValidationError('');
        }
    };

    // Validate inputs before running backtest
    const validateInputs = (): boolean => {
        if (!ticker.trim()) {
            setValidationError('Ticker symbol cannot be empty.');
            return false;
        }
         if (!startDate || !endDate) {
            setValidationError('Start date and end date are required.');
            return false;
        }
        if (new Date(startDate) >= new Date(endDate)) {
            setValidationError('Start date must be before end date.');
            return false;
        }
         if (initialCapital <= 0) {
             setValidationError('Initial capital must be a positive number.');
            return false;
         }
        if (!selectedStrategy) {
            setValidationError('Please select a strategy.');
            return false;
        }
        setValidationError(''); // Clear error if validation passes
        return true;
    };


    // Handle backtest execution submit
    const handleRunBacktest = useCallback(async (event: React.FormEvent) => {
        event.preventDefault(); // Prevent default form submission

        if (!validateInputs() || isLoading) {
            return; // Don't run if validation fails or already loading
        }

        onBacktestStart(); // Notify parent component loading started

        const request: BacktestRequest = {
            ticker: ticker.trim().toUpperCase(), // Normalize ticker
            startDate: startDate,
            endDate: endDate,
            strategyName: selectedStrategy,
            initialCapital: Number(initialCapital), // Ensure it's a number
            parameters: {} // TODO: Add UI elements to collect strategy-specific parameters
        };

        try {
            const results = await runBacktest(request);
            onBacktestComplete(results); // Pass results (potentially including backend error msg)
        } catch (error) {
            // Catch errors thrown by the handleApiError helper in api.ts
            console.error("Backtest API call failed:", error);
            onBacktestComplete(null, error as ApiError); // Pass the structured API error
        }
    }, [ticker, startDate, endDate, selectedStrategy, initialCapital, isLoading, onBacktestStart, onBacktestComplete]); // Include all dependencies


    // --- Render ---
    return (
        // Use a form element for better accessibility and potential submit handling
        <form onSubmit={handleRunBacktest} className="control-panel card">
            <h2>Simulation Controls</h2>

            {fetchStrategiesError && <p className="error-message">Error loading strategies: {fetchStrategiesError}</p>}
            {validationError && <p className="error-message validation-error">{validationError}</p>}

            {/* Ticker Input */}
            <div className="form-group">
                <label htmlFor="ticker">Ticker / Symbol:</label>
                <input
                    id="ticker"
                    type="text"
                    value={ticker}
                    onChange={handleInputChange(setTicker)}
                    placeholder="e.g., AAPL, ^GSPC"
                    disabled={isLoading}
                    required // Basic HTML5 validation
                    aria-describedby={validationError && validationError.includes('Ticker') ? 'ticker-error' : undefined}
                />
                 {validationError && validationError.includes('Ticker') && <span id="ticker-error" className="validation-error-inline">{validationError}</span>}
            </div>

            {/* Date Inputs */}
            <div className="form-group date-group">
                 <div>
                    <label htmlFor="start-date">Start Date:</label>
                    <input
                        id="start-date"
                        type="date"
                        value={startDate}
                        onChange={handleInputChange(setStartDate)}
                        disabled={isLoading}
                        required
                        max={endDate} // Basic HTML5 validation constraint
                        aria-describedby={validationError && validationError.includes('date') ? 'date-error' : undefined}
                    />
                 </div>
                 <div>
                    <label htmlFor="end-date">End Date:</label>
                    <input
                        id="end-date"
                        type="date"
                        value={endDate}
                        onChange={handleInputChange(setEndDate)}
                        disabled={isLoading}
                        required
                        min={startDate} // Basic HTML5 validation constraint
                        max={new Date().toISOString().split('T')[0]} // Prevent future dates
                        aria-describedby={validationError && validationError.includes('date') ? 'date-error' : undefined}
                    />
                 </div>
            </div>
             {validationError && validationError.includes('date') && <span id="date-error" className="validation-error-inline">{validationError}</span>}


            {/* Initial Capital Input */}
            <div className="form-group">
                <label htmlFor="initial-capital">Initial Capital ($):</label>
                <input
                    id="initial-capital"
                    type="number" // Use number type for better mobile keyboards
                    value={initialCapital} // Control component value
                    onChange={handleCapitalChange}
                    min="1" // HTML5 validation
                    step="any" // Allow decimals if needed, or "1000" etc.
                    placeholder="e.g., 100000"
                    disabled={isLoading}
                    required
                    aria-describedby={validationError && validationError.includes('capital') ? 'capital-error' : undefined}
                />
                 {validationError && validationError.includes('capital') && <span id="capital-error" className="validation-error-inline">{validationError}</span>}
            </div>

            {/* Strategy Selection */}
            <div className="form-group">
                <label htmlFor="strategy">Strategy:</label>
                <select
                    id="strategy"
                    value={selectedStrategy}
                    onChange={handleInputChange(setSelectedStrategy)}
                    disabled={isLoading || availableStrategies.length === 0 || !!fetchStrategiesError}
                    required
                    aria-describedby={validationError && validationError.includes('strategy') ? 'strategy-error' : undefined}
                >
                    {/* Placeholder option */}
                    {!selectedStrategy && <option value="" disabled>Select a strategy</option>}
                    {/* Loading/Error states */}
                    {fetchStrategiesError && <option value="" disabled>Error loading strategies</option>}
                    {availableStrategies.length === 0 && !fetchStrategiesError && <option value="" disabled>Loading...</option>}

                    {/* Strategy options */}
                    {availableStrategies.map(strategy => (
                        <option key={strategy.name} value={strategy.name}>
                            {strategy.displayName}
                        </option>
                    ))}
                </select>
                {strategyDescription && <p className="strategy-description">{strategyDescription}</p>}
                {/* TODO: Add dynamic inputs based on selectedStrategy.parameters here */}
                 {validationError && validationError.includes('strategy') && <span id="strategy-error" className="validation-error-inline">{validationError}</span>}
            </div>

            {/* Submit Button */}
            <button
                type="submit" // Important for form submission handling
                disabled={isLoading || !selectedStrategy || availableStrategies.length === 0 || !!fetchStrategiesError || !!validationError}
                className="run-button"
            >
                {isLoading ? 'Running Simulation...' : 'Run Backtest'}
            </button>
        </form>
    );
};

export default ControlPanel;
