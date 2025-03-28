import React from 'react';
import { BacktestResult, PerformanceMetrics } from '../types';
import './ResultsDisplay.css'; // For specific styling

interface ResultsDisplayProps {
    results: BacktestResult | null;
}

// Helper to format numbers nicely
const formatNumber = (num: number | null | undefined, digits: number = 2, isPercent: boolean = false): string => {
    if (num === null || typeof num === 'undefined' || isNaN(num)) {
        return 'N/A';
    }
    const formatted = num.toFixed(digits);
    return isPercent ? `${formatted}%` : formatted;
};

// Helper to format currency
const formatCurrency = (num: number | null | undefined, digits: number = 2): string => {
     if (num === null || typeof num === 'undefined' || isNaN(num)) {
        return 'N/A';
    }
    return `$${num.toLocaleString(undefined, { minimumFractionDigits: digits, maximumFractionDigits: digits })}`;
}

const ResultsDisplay: React.FC<ResultsDisplayProps> = ({ results }) => {
    if (!results || !results.metrics) {
        // Don't render anything or show a placeholder if no results yet
        // This component expects valid results to be passed
        return null;
    }

    const { metrics, ticker, strategyName, startDate, endDate } = results;

    return (
        <div className="results-display card">
            <h2>Backtest Results</h2>
            <p className="results-summary">
                Strategy: <strong>{strategyName}</strong> on <strong>{ticker}</strong><br />
                Period: {new Date(startDate).toLocaleDateString()} to {new Date(endDate).toLocaleDateString()}
            </p>

            {metrics ? (
                <ul className="metrics-list">
                    <li>
                        <strong>Initial Capital:</strong>
                        <span>{formatCurrency(metrics.initialCapital)}</span>
                    </li>
                    <li>
                        <strong>Final Portfolio Value:</strong>
                        <span>{formatCurrency(metrics.finalPortfolioValue)}</span>
                    </li>
                    <li className={metrics.totalReturnPercent >= 0 ? 'positive' : 'negative'}>
                        <strong>Total Return:</strong>
                        <span>{formatNumber(metrics.totalReturnPercent, 2, true)}</span>
                    </li>
                    <li className={metrics.annualizedReturnPercent >= 0 ? 'positive' : 'negative'}>
                        <strong>Annualized Return (CAGR):</strong>
                        <span>{formatNumber(metrics.annualizedReturnPercent, 2, true)}</span>
                    </li>
                     <li>
                        <strong>Sharpe Ratio (Annualized):</strong>
                        <span>{formatNumber(metrics.sharpeRatio, 3)}</span>
                    </li>
                     <li className={metrics.maxDrawdownPercent <= -10 ? 'negative' : (metrics.maxDrawdownPercent <= -5 ? 'warning' : 'positive')}>
                        <strong>Max Drawdown:</strong>
                        <span>{formatNumber(metrics.maxDrawdownPercent, 2, true)}</span>
                    </li>
                    <li>
                        <strong>Trade Pairs (Approx):</strong>
                        <span>{metrics.numberOfTradePairs ?? 'N/A'}</span>
                    </li>

                </ul>
            ) : (
                <p>Performance metrics are unavailable.</p>
            )}

            {/* Optional: Display Trade Log Summary or Full Log */}
            {/*
            <h3>Trade Log Summary</h3>
            <p>Total Trades: {results.tradeLog?.length ?? 0}</p>
            <p>Buy Trades: {results.tradeLog?.filter(t => t.action === 'BUY').length ?? 0}</p>
            <p>Sell Trades: {results.tradeLog?.filter(t => t.action === 'SELL').length ?? 0}</p>
            */}

             {/* Optional: Display disclaimer again */}
             <p className="results-disclaimer">
                 Note: Simulation ignores commissions, slippage, taxes, and other real-world costs. Past performance is not indicative of future results.
             </p>
        </div>
    );
};

export default ResultsDisplay;
