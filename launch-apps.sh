#!/bin/bash

# This script launches both the frontend and backend applications.

# Navigate to the frontend directory and start the React app
cd StockTradingApp/trading-simulator-ui
npm start &

# Navigate to the backend directory and start the .NET API
cd ../TradingSimulatorAPI
dotnet run

# Wait for both processes to complete
wait