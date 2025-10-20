// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IInsuranceManager
 * @notice Interface for managing insurance pools and penalty distributions
 * @dev Handles health factor violations and end-of-cycle insurance distributions
 */
interface IInsuranceManager {
    // --- Structs ---
    struct InsurancePool {
        mapping(address => uint256) assetBalances; // wrapperToken => amount
        uint256 totalValue; // Weighted total value
        uint256 contributionCount;
        bool isActive;
    }
    
    struct UserScore {
        uint256 perfectRounds;    // Rounds completed without violations
        uint256 totalRounds;      // Total rounds participated
        uint256 penaltyAmount;    // Total penalty contributed to insurance
        uint256 lastScoreUpdate; // Timestamp of last update
    }
    
    struct DistributionInfo {
        address user;
        uint256 score;           // Final score (1e18 = perfect)
        uint256 sharePercentage; // Percentage of insurance pool (1e18 = 100%)
        mapping(address => uint256) assetShares; // wrapperToken => amount
    }
    
    // --- Events ---
    event InsuranceContribution(
        address indexed vault,
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 penaltyScore
    );
    event InsuranceDistributed(
        address indexed vault,
        uint256 totalValue,
        uint256 recipientCount
    );
    event UserScoreUpdated(
        address indexed vault,
        address indexed user,
        uint256 newScore,
        uint256 totalRounds
    );
    event InsurancePoolCreated(address indexed vault);
    event InsurancePoolClosed(address indexed vault, uint256 finalValue);
    
    // --- Core Functions ---
    /**
     * @notice Add insurance contribution from health factor violation
     * @param vault Vault address
     * @param user User who violated health factor
     * @param wrapperToken Asset being contributed
     * @param amount Amount to contribute
     * @param penaltyScore Penalty score (1e18 = no penalty, lower = more penalty)
     */
    function addInsuranceContribution(
        address vault,
        address user,
        address wrapperToken,
        uint256 amount,
        uint256 penaltyScore
    ) external;
    
    /**
     * @notice Distribute insurance pool to vault members at cycle end
     * @param vault Vault address
     * @param members Array of member addresses
     * @param scores Array of member scores (1e18 = perfect)
     */
    function distributeInsurance(
        address vault,
        address[] memory members,
        uint256[] memory scores
    ) external;
    
    /**
     * @notice Update user score after round completion
     * @param vault Vault address
     * @param user User address
     * @param wasViolation True if user violated health factor this round
     * @param penaltyAmount Amount contributed as penalty (if any)
     */
    function updateUserScore(
        address vault,
        address user,
        bool wasViolation,
        uint256 penaltyAmount
    ) external;
    
    /**
     * @notice Calculate user's final score for insurance distribution
     * @param vault Vault address
     * @param user User address
     * @return score Final score (1e18 = perfect, lower = penalties applied)
     */
    function calculateFinalScore(
        address vault,
        address user
    ) external view returns (uint256 score);
    
    /**
     * @notice Claim insurance distribution for user
     * @param vault Vault address
     */
    function claimInsuranceDistribution(address vault) external;
    
    // --- Pool Management ---
    /**
     * @notice Create insurance pool for new vault cycle
     * @param vault Vault address
     */
    function createInsurancePool(address vault) external;
    
    /**
     * @notice Close insurance pool and prepare for distribution
     * @param vault Vault address
     */
    function closeInsurancePool(address vault) external;
    
    /**
     * @notice Emergency withdraw from insurance pool (only vault manager)
     * @param vault Vault address
     * @param wrapperToken Asset to withdraw
     * @param amount Amount to withdraw
     * @param recipient Recipient address
     */
    function emergencyWithdraw(
        address vault,
        address wrapperToken,
        uint256 amount,
        address recipient
    ) external;
    
    // --- View Functions ---
    /**
     * @notice Get insurance pool total value
     * @param vault Vault address
     * @return totalValue Weighted total value of insurance pool
     */
    function getInsurancePoolValue(address vault) external view returns (uint256 totalValue);
    
    /**
     * @notice Get insurance pool balance for specific asset
     * @param vault Vault address
     * @param wrapperToken Wrapper token address
     * @return balance Asset balance in insurance pool
     */
    function getInsurancePoolBalance(
        address vault,
        address wrapperToken
    ) external view returns (uint256 balance);
    
    /**
     * @notice Get user's score information
     * @param vault Vault address
     * @param user User address
     * @return userScore User score struct
     */
    function getUserScore(
        address vault,
        address user
    ) external view returns (UserScore memory userScore);
    
    /**
     * @notice Calculate user's share of insurance distribution
     * @param vault Vault address
     * @param user User address
     * @return sharePercentage Percentage of total pool (1e18 = 100%)
     * @return estimatedValue Estimated value of user's share
     */
    function calculateUserShare(
        address vault,
        address user
    ) external view returns (uint256 sharePercentage, uint256 estimatedValue);
    
    /**
     * @notice Get all users with insurance distributions pending
     * @param vault Vault address
     * @return users Array of user addresses with pending distributions
     */
    function getPendingDistributions(address vault) external view returns (address[] memory users);
    
    /**
     * @notice Check if insurance pool exists and is active
     * @param vault Vault address
     * @return isActive True if pool exists and is active
     */
    function isInsurancePoolActive(address vault) external view returns (bool isActive);
    
    /**
     * @notice Get insurance pool statistics
     * @param vault Vault address
     * @return totalValue Total weighted value
     * @return contributionCount Number of contributions
     * @return isActive Pool status
     */
    function getInsurancePoolStats(address vault) external view returns (
        uint256 totalValue,
        uint256 contributionCount,
        bool isActive
    );
}