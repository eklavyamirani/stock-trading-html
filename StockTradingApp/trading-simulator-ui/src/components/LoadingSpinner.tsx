import React from 'react';
import './LoadingSpinner.css'; // We'll define styles here or in App.css

const LoadingSpinner: React.FC = () => {
    return (
        <div className="loading-spinner-overlay">
            <div className="loading-spinner"></div>
        </div>
    );
};

export default LoadingSpinner;
