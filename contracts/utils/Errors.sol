// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Errors {
    // --- Token Errors ---
    error InvalidTreasury();
    error InsufficientHBARBacking();
    error OnlyVaultCanLock();
    error TokensLocked();
    error InsufficientUnlockedBalance();
    
    // --- Vault Errors ---
    error BelowMinimumStake();
    error AlreadyMember();
    error NotMember();
    error NotActiveMember();
    error RoundNotInDepositPhase();
    error RoundNotActive();
    error RoundNotInPayout();
    error NotYourTurn();
    error NoActiveDebt();
    error MustRepayDebt();
    error MustCompleteOneCycle();
    error NoMembers();
    error PreviousRoundNotCompleted();
    error AlreadyClaimed();
    
    // --- Risk Management Errors ---
    error NoMarginCall();
    error GracePeriodActive();
    error HealthFactorOK();
    
    // --- Manager Errors ---
    error InvalidVaultId();
    error FeeTooHigh();
    error PenaltyTooHigh();
    error NoFeesToWithdraw();
    error Unauthorized();
    
    // --- General Errors ---
    error TransferFailed();
    error InvalidAmount();
    error InvalidAddress();
}