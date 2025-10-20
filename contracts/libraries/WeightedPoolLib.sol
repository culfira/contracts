// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title WeightedPoolLib - Weighted pool math library
/// @notice Implements weighted pool calculations inspired by Balancer
library WeightedPoolLib {
    
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant MIN_WEIGHT = 1e16;  // 1%
    uint256 internal constant MAX_WEIGHT = 99e16; // 99%
    
    // ============ Structs ============
    
    struct PoolState {
        uint256[] balances;
        uint256[] weights;
        uint256 totalWeight;
    }
    
    // ============ Functions ============
    
    /// @notice Calculate spot price between two tokens
    /// @param balanceIn Balance of token in
    /// @param weightIn Weight of token in
    /// @param balanceOut Balance of token out
    /// @param weightOut Weight of token out
    function calculateSpotPrice(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut
    ) internal pure returns (uint256) {
        uint256 numer = (balanceIn * PRECISION) / weightIn;
        uint256 denom = (balanceOut * PRECISION) / weightOut;
        return (numer * PRECISION) / denom;
    }
    
    /// @notice Calculate invariant (product of weighted balances)
    function calculateInvariant(
        uint256[] memory balances,
        uint256[] memory weights
    ) internal pure returns (uint256 invariant) {
        invariant = PRECISION;
        
        for (uint256 i = 0; i < balances.length; i++) {
            invariant = (invariant * _pow(balances[i], weights[i])) / PRECISION;
        }
    }
    
    /// @notice Calculate pool value ratio change
    function calculateRatioChange(
        uint256 initialBalance,
        uint256 currentBalance,
        uint256 weight
    ) internal pure returns (uint256) {
        if (initialBalance == 0) return 0;
        
        uint256 balanceRatio = (currentBalance * PRECISION) / initialBalance;
        return _pow(balanceRatio, weight);
    }
    
    /// @notice Simple power function for weights
    function _pow(uint256 base, uint256 exp) internal pure returns (uint256) {
        if (exp == 0) return PRECISION;
        
        uint256 result = PRECISION;
        uint256 normalizedExp = (exp * 100) / PRECISION;
        
        for (uint256 i = 0; i < normalizedExp; i++) {
            result = (result * base) / PRECISION;
        }
        
        return result;
    }
    
    /// @notice Validate pool weights
    function validateWeights(uint256[] memory weights) internal pure returns (bool) {
        uint256 total;
        
        for (uint256 i = 0; i < weights.length; i++) {
            if (weights[i] < MIN_WEIGHT || weights[i] > MAX_WEIGHT) {
                return false;
            }
            total += weights[i];
        }
        
        return total == PRECISION;
    }
    
    /// @notice Calculate health factor based on weighted pool deltas
    function calculateHealthFactor(
        uint256[] memory initialBalances,
        uint256[] memory currentBalances,
        uint256[] memory weights
    ) internal pure returns (uint256) {
        uint256 minRatio = type(uint256).max;
        
        for (uint256 i = 0; i < initialBalances.length; i++) {
            if (initialBalances[i] == 0) continue;
            
            uint256 ratio = (currentBalances[i] * PRECISION) / initialBalances[i];
            
            // Weight the ratio
            uint256 weightedRatio = (ratio * weights[i]) / PRECISION;
            
            if (weightedRatio < minRatio) {
                minRatio = weightedRatio;
            }
        }
        
        return minRatio;
    }
}