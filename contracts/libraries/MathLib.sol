// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library MathLib {
    // --- Safe Math Operations ---
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
    
    // --- Percentage Calculations ---
    function percentage(
        uint256 amount,
        uint256 bps
    ) internal pure returns (uint256) {
        return (amount * bps) / 10000;
    }
    
    function percentageOf(
        uint256 part,
        uint256 whole
    ) internal pure returns (uint256) {
        if (whole == 0) return 0;
        return (part * 10000) / whole;
    }
    
    // --- Ratio Calculations ---
    function calculateRatio(
        uint256 numerator,
        uint256 denominator,
        uint256 precision
    ) internal pure returns (uint256) {
        if (denominator == 0) return 0;
        return (numerator * precision) / denominator;
    }
}