// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Constants {
    // --- Token Constants ---
    uint256 internal constant RESERVE_RATIO = 95;
    uint256 internal constant BASIS_POINTS = 10000;
    
    // --- Vault Constants ---
    uint256 internal constant MIN_STAKE = 1000 * 1e18;
    uint256 internal constant ROUND_DURATION = 30 days;
    uint256 internal constant DEPOSIT_PHASE = 3 days;
    uint256 internal constant PAYOUT_PHASE = 2 days;
    uint256 internal constant COOLDOWN_PHASE = 1 days;
    
    // --- Risk Constants ---
    uint256 internal constant HEALTH_FACTOR_PRECISION = 1e18;
    uint256 internal constant HEALTH_FACTOR_THRESHOLD = 1e18;
    uint256 internal constant WARNING_THRESHOLD = 1.1e18;
    uint256 internal constant LIQUIDATION_PENALTY = 2000; // 20%
    uint256 internal constant GRACE_PERIOD = 48 hours;
    
    // --- Fee Constants ---
    uint256 internal constant MAX_PROTOCOL_FEE = 1000; // 10%
    uint256 internal constant MAX_PENALTY_RATE = 5000; // 50%
    uint256 internal constant DEFAULT_PROTOCOL_FEE = 500; // 5%
    uint256 internal constant DEFAULT_PENALTY_RATE = 2000; // 20%
}