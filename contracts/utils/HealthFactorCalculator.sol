// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../libraries/WeightedPoolLib.sol";

/// @title HealthFactorCalculator - Standalone health factor calculator
/// @notice Provides advanced health factor calculations for multi-asset pools
contract HealthFactorCalculator {
    
    using WeightedPoolLib for *;
    
    // ============ Constants ============
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant CRITICAL_THRESHOLD = 0.95e18;  // 95%
    uint256 public constant WARNING_THRESHOLD = 0.98e18;   // 98%
    
    // ============ Structs ============
    
    struct HealthResult {
        uint256 overallHealth;
        uint256 minAssetHealth;
        uint256 maxAssetHealth;
        uint256 weightedHealth;
        bool isCritical;
        bool isWarning;
        uint256 totalDeficit;
    }
    
    struct AssetHealth {
        address token;
        uint256 initialAmount;
        uint256 currentAmount;
        uint256 weight;
        uint256 healthFactor;
        uint256 deficit;
    }
    
    // ============ Functions ============
    
    /// @notice Calculate comprehensive health factor
    function calculateHealth(
        address[] memory tokens,
        uint256[] memory initialAmounts,
        uint256[] memory currentAmounts,
        uint256[] memory weights
    ) external pure returns (HealthResult memory result) {
        require(
            tokens.length == initialAmounts.length &&
            initialAmounts.length == currentAmounts.length &&
            currentAmounts.length == weights.length,
            "Array length mismatch"
        );
        
        result.minAssetHealth = type(uint256).max;
        result.maxAssetHealth = 0;
        result.totalDeficit = 0;
        
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 assetHealth;
            
            if (initialAmounts[i] == 0) {
                assetHealth = PRECISION;
            } else {
                assetHealth = (currentAmounts[i] * PRECISION) / initialAmounts[i];
            }
            
            // Track min/max
            if (assetHealth < result.minAssetHealth) {
                result.minAssetHealth = assetHealth;
            }
            if (assetHealth > result.maxAssetHealth) {
                result.maxAssetHealth = assetHealth;
            }
            
            // Calculate weighted contribution
            weightedSum += (assetHealth * weights[i]);
            totalWeight += weights[i];
            
            // Calculate deficit
            if (currentAmounts[i] < initialAmounts[i]) {
                result.totalDeficit += (initialAmounts[i] - currentAmounts[i]);
            }
        }
        
        // Overall weighted health
        result.weightedHealth = totalWeight > 0 ? weightedSum / totalWeight : PRECISION;
        
        // Use minimum asset health as overall health (most conservative)
        result.overallHealth = result.minAssetHealth;
        
        // Set flags
        result.isCritical = result.overallHealth < CRITICAL_THRESHOLD;
        result.isWarning = result.overallHealth >= CRITICAL_THRESHOLD && 
                           result.overallHealth < WARNING_THRESHOLD;
    }
    
    /// @notice Calculate detailed health per asset
    function calculateAssetHealthDetails(
        address[] memory tokens,
        uint256[] memory initialAmounts,
        uint256[] memory currentAmounts,
        uint256[] memory weights
    ) external pure returns (AssetHealth[] memory) {
        AssetHealth[] memory assetHealths = new AssetHealth[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 healthFactor;
            uint256 deficit = 0;
            
            if (initialAmounts[i] == 0) {
                healthFactor = PRECISION;
            } else {
                healthFactor = (currentAmounts[i] * PRECISION) / initialAmounts[i];
                
                if (currentAmounts[i] < initialAmounts[i]) {
                    deficit = initialAmounts[i] - currentAmounts[i];
                }
            }
            
            assetHealths[i] = AssetHealth({
                token: tokens[i],
                initialAmount: initialAmounts[i],
                currentAmount: currentAmounts[i],
                weight: weights[i],
                healthFactor: healthFactor,
                deficit: deficit
            });
        }
        
        return assetHealths;
    }
    
    /// @notice Calculate required rebalancing amounts
    function calculateRebalancing(
        uint256[] memory initialAmounts,
        uint256[] memory currentAmounts,
        uint256[] memory weights
    ) external pure returns (int256[] memory rebalanceAmounts) {
        rebalanceAmounts = new int256[](initialAmounts.length);
        
        for (uint256 i = 0; i < initialAmounts.length; i++) {
            // Positive means need to add, negative means surplus
            rebalanceAmounts[i] = int256(initialAmounts[i]) - int256(currentAmounts[i]);
        }
    }
    
    /// @notice Calculate penalty based on health factor
    function calculatePenalty(
        uint256 healthFactor,
        uint256 totalValue,
        uint256 basePenaltyRate
    ) external pure returns (uint256 penalty) {
        if (healthFactor >= PRECISION) {
            return 0;
        }
        
        // Penalty increases as health factor decreases
        uint256 healthDeficit = PRECISION - healthFactor;
        
        // Base penalty * deficit ratio
        penalty = (totalValue * basePenaltyRate * healthDeficit) / (PRECISION * PRECISION);
    }
    
    /// @notice Simulate health factor after operation
    function simulateHealthAfterOperation(
        uint256[] memory currentAmounts,
        uint256[] memory deltas,  // Can be positive or negative
        uint256[] memory weights
    ) external pure returns (uint256 newHealth) {
        uint256[] memory newAmounts = new uint256[](currentAmounts.length);
        
        for (uint256 i = 0; i < currentAmounts.length; i++) {
            if (deltas[i] >= 0) {
                newAmounts[i] = currentAmounts[i] + uint256(deltas[i]);
            } else {
                uint256 decrease = uint256(-int256(deltas[i]));
                newAmounts[i] = currentAmounts[i] > decrease ? 
                    currentAmounts[i] - decrease : 0;
            }
        }
        
        // Calculate health with new amounts
        newHealth = WeightedPoolLib.calculateHealthFactor(
            currentAmounts,
            newAmounts,
            weights
        );
    }
}