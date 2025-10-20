// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IMultiAssetVault
 * @notice Interface for multi-asset vaults supporting weighted pools and health factors
 * @dev Based on Balancer-style weighted pools with Culfira-specific stokvel mechanics
 */
interface IMultiAssetVault {
    // --- Enums ---
    enum RoundState {
        DEPOSIT,    // Users can join and deposit
        ACTIVE,     // Round is running, winner selected
        PAYOUT,     // Winner claimed, waiting for completion
        COMPLETED   // Round finished
    }
    
    // --- Structs ---
    struct AssetConfig {
        address wrapperToken;
        uint256 weight;         // Balancer-style weight (sum should be 1e18)
        uint256 targetAmount;   // Target amount for this asset in pool
        bool isActive;
    }
    
    struct Member {
        uint256 joinedRound;
        bool hasReceivedPayout;
        bool isActive;
        mapping(address => uint256) assetContributions; // wrapperToken => amount
        uint256 totalValueContributed; // Weighted value
    }
    
    struct Round {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 cycleDuration;
        address recipient;
        RoundState state;
        mapping(address => uint256) poolComposition; // wrapperToken => amount
        mapping(address => uint256) initialComposition; // For health factor calc
        uint256 totalPoolValue; // Weighted total value
    }
    
    struct HealthFactorInfo {
        uint256 healthFactor;      // Current health factor (1e18 = healthy)
        uint256 requiredTopUp;     // Amount needed to restore health
        address[] deficitAssets;   // Assets below target
        uint256[] deficitAmounts;  // Amounts needed per asset
    }
    
    struct InsuranceContribution {
        uint256 amount;
        uint256 penaltyScore; // 1e18 = perfect, lower = penalty
        address asset;
    }
    
    // --- Events ---
    event MemberJoined(address indexed user, uint256 totalValue, uint256 roundId);
    event MemberExited(address indexed user);
    event RoundStarted(uint256 indexed roundId, address indexed recipient, uint256 totalPoolValue);
    event RoundCompleted(uint256 indexed roundId);
    event PayoutClaimed(address indexed recipient, uint256 totalValue, uint256 roundId);
    event HealthFactorUpdated(address indexed user, uint256 healthFactor);
    event InsuranceTriggered(address indexed user, uint256 amount, address asset);
    event AssetConfigUpdated(address indexed wrapperToken, uint256 weight, uint256 targetAmount);
    
    // --- Core Functions ---
    /**
     * @notice Join vault with multi-asset deposit
     * @param wrapperTokens Array of wrapper token addresses
     * @param amounts Array of amounts to deposit
     */
    function joinVault(
        address[] memory wrapperTokens,
        uint256[] memory amounts
    ) external;
    
    /**
     * @notice Exit vault (only if no active debt/health issues)
     */
    function exitVault() external;
    
    /**
     * @notice Start new round (only manager)
     */
    function startRound() external;
    
    /**
     * @notice Start round with custom duration
     * @param customDuration Duration in seconds
     */
    function startRoundWithDuration(uint256 customDuration) external;
    
    /**
     * @notice Claim round payout (only current recipient)
     */
    function claimRoundPayout() external;
    
    /**
     * @notice Complete current round (only manager)
     */
    function completeRound() external;
    
    // --- Health Factor & Insurance ---
    /**
     * @notice Check user's health factor
     * @param user User address
     * @return healthInfo Current health factor information
     */
    function checkHealthFactor(address user) external view returns (HealthFactorInfo memory healthInfo);
    
    /**
     * @notice Top up assets to maintain health factor
     * @param wrapperTokens Assets to top up
     * @param amounts Amounts to add
     */
    function topUpAssets(
        address[] memory wrapperTokens,
        uint256[] memory amounts
    ) external;
    
    /**
     * @notice Trigger insurance transfer for health factor violations
     * @param user User who violated health factor
     */
    function triggerInsurance(address user) external;
    
    // --- Asset Management ---
    /**
     * @notice Add or update asset configuration (only manager)
     * @param wrapperToken Wrapper token address
     * @param weight Asset weight in pool (1e18 = 100%)
     * @param targetAmount Target amount for this asset
     */
    function setAssetConfig(
        address wrapperToken,
        uint256 weight,
        uint256 targetAmount
    ) external;
    
    /**
     * @notice Remove asset from vault (only manager)
     * @param wrapperToken Wrapper token to remove
     */
    function removeAsset(address wrapperToken) external;
    
    // --- View Functions ---
    /**
     * @notice Get current round information
     */
    function getCurrentRound() external view returns (
        uint256 id,
        uint256 startTime,
        uint256 endTime,
        uint256 cycleDuration,
        address recipient,
        RoundState state,
        uint256 totalPoolValue
    );
    
    /**
     * @notice Get member information
     * @param user User address
     */
    function getMemberInfo(address user) external view returns (
        uint256 joinedRound,
        bool hasReceivedPayout,
        bool isActive,
        uint256 totalValueContributed
    );
    
    /**
     * @notice Get member's contribution for specific asset
     * @param user User address
     * @param wrapperToken Wrapper token address
     * @return amount Contributed amount
     */
    function getMemberAssetContribution(
        address user,
        address wrapperToken
    ) external view returns (uint256 amount);
    
    /**
     * @notice Get current pool composition
     * @param wrapperToken Wrapper token address
     * @return amount Current amount in pool
     */
    function getPoolComposition(address wrapperToken) external view returns (uint256 amount);
    
    /**
     * @notice Get asset configuration
     * @param wrapperToken Wrapper token address
     * @return config Asset configuration
     */
    function getAssetConfig(address wrapperToken) external view returns (AssetConfig memory config);
    
    /**
     * @notice Get all configured assets
     * @return assets Array of asset configurations
     */
    function getAllAssets() external view returns (AssetConfig[] memory assets);
    
    /**
     * @notice Get next round recipient
     * @return recipient Next member to receive payout
     */
    function getNextRecipient() external view returns (address recipient);
    
    /**
     * @notice Calculate weighted value of asset amounts
     * @param wrapperTokens Array of wrapper tokens
     * @param amounts Array of amounts
     * @return totalValue Weighted total value
     */
    function calculateWeightedValue(
        address[] memory wrapperTokens,
        uint256[] memory amounts
    ) external view returns (uint256 totalValue);
    
    /**
     * @notice Get vault statistics
     * @return totalMembers Total active members
     * @return currentRoundId Current round ID
     * @return totalPoolValue Total weighted pool value
     */
    function getVaultStats() external view returns (
        uint256 totalMembers,
        uint256 currentRoundId,
        uint256 totalPoolValue
    );
}