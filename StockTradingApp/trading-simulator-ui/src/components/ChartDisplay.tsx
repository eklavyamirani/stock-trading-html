import React, { useRef, useEffect } from 'react';
import { BacktestResult, ChartDataPoint } from '../types';
import {
    Chart as ChartJS,
    CategoryScale, // x axis
    LinearScale, // y axis
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend,
    TimeScale, // Use TimeScale for date axes
    ChartOptions,
    ChartData
} from 'chart.js';
import 'chartjs-adapter-date-fns'; // Import adapter for date handling
import { Line } from 'react-chartjs-2';

// Register Chart.js components
ChartJS.register(
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend,
    TimeScale // Register TimeScale
);

interface ChartDisplayProps {
    results: BacktestResult | null;
}

// Helper function to format chart data points
const formatChartData = (dataPoints: ChartDataPoint[]) => {
    return dataPoints.map(point => ({
        x: new Date(point.date).getTime(), // Use timestamp for time scale
        y: point.value
    }));
};


const ChartDisplay: React.FC<ChartDisplayProps> = ({ results }) => {
    const chartRef = useRef<ChartJS<'line'>>(null);

    if (!results || !results.portfolioValueHistory || !results.benchmarkValueHistory) {
        return <div className="chart-display card"><p>Chart data is unavailable.</p></div>;
    }

    const { portfolioValueHistory, benchmarkValueHistory, ticker, strategyName } = results;

    // Prepare data for Chart.js
    const chartData: ChartData<'line'> = {
         // Labels are often inferred by time scale, but can be provided if needed
        // labels: portfolioValueHistory.map(p => new Date(p.date)), // Use Date objects for time scale
        datasets: [
            {
                label: `${strategyName} Portfolio Value`,
                data: formatChartData(portfolioValueHistory),
                borderColor: 'rgb(54, 162, 235)', // Blue
                backgroundColor: 'rgba(54, 162, 235, 0.5)',
                tension: 0.1, // Slightly curve the line
                pointRadius: 0, // Hide points for cleaner line
                borderWidth: 2,
                yAxisID: 'y', // Assign to the primary y-axis
            },
            {
                label: `${ticker} Benchmark (Normalized)`,
                data: formatChartData(benchmarkValueHistory),
                borderColor: 'rgb(150, 150, 150)', // Grey
                backgroundColor: 'rgba(150, 150, 150, 0.5)',
                borderDash: [5, 5], // Dashed line for benchmark
                tension: 0.1,
                pointRadius: 0,
                borderWidth: 1.5,
                 yAxisID: 'y', // Assign to the primary y-axis (since it's normalized)
            },
             // Optional: Add buy/sell markers if signal data is available
            // {
            //     label: 'Buy Signals',
            //     data: buySignalPoints, // formatChartData(points where signal=1)
            //     borderColor: 'rgba(75, 192, 192, 0)', // Transparent line
            //     backgroundColor: 'rgba(75, 192, 192, 1)', // Green points
            //     pointStyle: 'triangle',
            //     pointRadius: 6,
            //     pointRotation: 0, // Pointing up
            //     showLine: false, // Don't connect points with a line
            // },
            // {
            //     label: 'Sell Signals',
            //     data: sellSignalPoints, // formatChartData(points where signal=-1)
            //     borderColor: 'rgba(255, 99, 132, 0)', // Transparent line
            //     backgroundColor: 'rgba(255, 99, 132, 1)', // Red points
            //     pointStyle: 'triangle',
            //     pointRadius: 6,
            //     pointRotation: 180, // Pointing down
            //     showLine: false,
            // }
        ],
    };

    // Configure chart options
    const options: ChartOptions<'line'> = {
        responsive: true,
        maintainAspectRatio: false, // Allow chart to fill container height
        plugins: {
            legend: {
                position: 'top' as const,
            },
            title: {
                display: true,
                text: `Strategy Performance vs Benchmark (${ticker})`,
                font: { size: 16 }
            },
            tooltip: {
                mode: 'index' as const, // Show tooltips for all datasets at the same x-index
                intersect: false,
                callbacks: {
                     label: function(context) {
                        let label = context.dataset.label || '';
                        if (label) {
                            label += ': ';
                        }
                        if (context.parsed.y !== null) {
                            // Format as currency
                            label += new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(context.parsed.y);
                        }
                        return label;
                    }
                }
            },
        },
        scales: {
            x: {
                type: 'time' as const, // Use time scale
                time: {
                    unit: 'month' as const, // Display months on the axis, adjust as needed ('day', 'year')
                    tooltipFormat: 'PP' // Date format for tooltip (e.g., 'Oct 27, 2023') - Uses date-fns formats
                },
                title: {
                    display: true,
                    text: 'Date'
                },
                grid: {
                     display: false // Hide vertical grid lines if desired
                }
            },
            y: { // Primary Y-axis for portfolio/benchmark value
                type: 'linear' as const,
                display: true,
                position: 'left' as const,
                title: {
                    display: true,
                    text: 'Value ($)'
                },
                 // Format ticks as currency
                 ticks: {
                     callback: function(value, index, values) {
                         if (typeof value === 'number') {
                             return '$' + value.toLocaleString();
                         }
                         return value;
                     }
                 }
            }
            // Optional: Add a secondary Y-axis if needed for indicators like RSI
            // y1: {
            //    type: 'linear' as const,
            //    display: true, // Set to true if you have data for it
            //    position: 'right' as const,
            //    title: { display: true, text: 'RSI' },
            //    grid: { drawOnChartArea: false }, // Only show grid for primary axis
            //    min: 0, max: 100 // Typical RSI range
            // }
        },
         interaction: {
            mode: 'index' as const,
            intersect: false,
        },
    };

    // Destroy previous chart instance when results change
     useEffect(() => {
        const chart = chartRef.current;
        return () => {
            chart?.destroy();
        };
    }, [results]); // Dependency on results ensures cleanup when new results arrive

    return (
        <div className="chart-display card">
            <div style={{ position: 'relative', height: '400px' }}> {/* Set container height */}
                <Line ref={chartRef} options={options} data={chartData} />
            </div>
        </div>
    );
};

export default ChartDisplay;
