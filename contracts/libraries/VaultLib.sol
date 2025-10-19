// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library VaultLib {
    // --- Constants ---
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant HEALTH_FACTOR_THRESHOLD = 1e18;
    uint256 internal constant WARNING_THRESHOLD = 1.1e18;
    uint256 internal constant GRACE_PERIOD = 48 hours;
    
    // --- Structs ---
    struct HealthFactorResult {
        uint256 healthFactor;
        bool isCritical;
        bool isWarning;
        uint256 deficit;
    }
    
    // --- Health Factor Calculation ---
    function calculateHealthFactor(
        uint256 currentValue,
        uint256 initialValue
    ) internal pure returns (uint256) {
        if (initialValue == 0) return type(uint256).max;
        return (currentValue * PRECISION) / initialValue;
    }
    
    function assessHealthFactor(
        uint256 healthFactor
    ) internal pure returns (HealthFactorResult memory) {
        HealthFactorResult memory result;
        result.healthFactor = healthFactor;
        result.isCritical = healthFactor < HEALTH_FACTOR_THRESHOLD;
        result.isWarning = healthFactor >= HEALTH_FACTOR_THRESHOLD && 
                          healthFactor < WARNING_THRESHOLD;
        result.deficit = 0;
        
        return result;
    }
    
    // --- Penalty Calculation ---
    function calculatePenalty(
        uint256 stakedAmount,
        uint256 penaltyRate
    ) internal pure returns (uint256) {
        return (stakedAmount * penaltyRate) / 10000;
    }
    
    // --- Deficit Calculation ---
    function calculateDeficit(
        uint256 initialValue,
        uint256 currentValue
    ) internal pure returns (uint256) {
        if (currentValue >= initialValue) return 0;
        return initialValue - currentValue;
    }
    
    // --- Member Position ---
    function getNextPosition(
        uint256 currentPosition,
        uint256 totalMembers
    ) internal pure returns (uint256) {
        if (totalMembers == 0) return 0;
        return (currentPosition + 1) % totalMembers;
    }
}