// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IMultiAssetVault - Interface for Multi-asset stokvel vault with weighted pools
interface IMultiAssetVault {
    
    // ============ Structs ============
    
    struct PoolAsset {
        address wrapperToken;
        uint256 weight;          // Weight in basis points (10000 = 100%)
        uint256 initialAmount;   // Amount at round start
        uint256 currentAmount;   // Current amount
    }
    
    struct Member {
        uint256 depositedAmounts;  // Total value deposited
        uint256 position;
        uint256 joinedRound;
        uint256 score;            // Performance score (10000 = 100%)
        bool hasReceivedPayout;
        bool isActive;
    }
    
    struct Round {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        address winner;
        PoolAsset[] poolAssets;
        RoundState state;
    }
    
    enum RoundState {
        DEPOSIT,
        ACTIVE,
        COMPLETED
    }
    
    // ============ Events ============
    
    event MemberJoined(address indexed user, uint256 position);
    event RoundStarted(uint256 indexed roundId, address indexed winner);
    event RoundCompleted(uint256 indexed roundId);
    event AssetDeposited(address indexed user, address indexed wrapper, uint256 amount);
    event WinnerClaimed(address indexed winner, uint256 roundId);
    event HealthFactorViolation(address indexed user, uint256 deficit);
    event InsuranceDistributed(address indexed user, uint256 amount);
    event WrapperRegistered(address indexed wrapper);
    
    // ============ Errors ============
    
    error InvalidAmount();
    error NotMember();
    error AlreadyMember();
    error NotWinner();
    error RoundNotActive();
    error InvalidAssetRatio();
    error InsufficientBalance();
    error HealthFactorTooLow();
    error UnauthorizedVault();
    
    // ============ Admin Functions ============
    
    /// @notice Register a wrapper token for use in the vault
    /// @param wrapper Address of the wrapper token to register
    function registerWrapper(address wrapper) external;
    
    /// @notice Start a new round with specific assets and weights
    /// @param assets Array of wrapper token addresses
    /// @param weights Array of weights for each asset (in basis points)
    function startRound(address[] calldata assets, uint256[] calldata weights) external;
    
    /// @notice Complete the current round
    function completeRound() external;
    
    /// @notice Distribute insurance funds to members
    function distributeInsurance() external;
    
    // ============ View Functions ============
    
    /// @notice Join the vault with multi-asset deposits
    /// @param wrappers Array of wrapper token addresses
    /// @param amounts Array of amounts to deposit
    /// @param weights Array of weights for validation
    function joinVault(
        address[] calldata wrappers,
        uint256[] calldata amounts,
        uint256[] calldata weights
    ) external;
    
    /// @notice Claim winner assets for the current round
    function claimWinnerAssets() external;
    
    // ============ View Functions ============
    
    /// @notice Get the next recipient based on position
    /// @return nextRecipient Address of the next recipient
    function getNextRecipient() external view returns (address);
    
    /// @notice Get member information
    /// @param user Address of the member
    /// @return member Member struct with all member data
    function getMemberInfo(address user) external view returns (Member memory);
    
    /// @notice Get round information
    /// @param roundId ID of the round
    /// @return round Round struct with all round data
    function getRoundInfo(uint256 roundId) external view returns (Round memory);
    
    /// @notice Get health factor for a user
    /// @param user Address of the user
    /// @return healthFactor Health factor value
    function getHealthFactor(address user) external view returns (uint256);
    
    /// @notice Get insurance pool balance for a wrapper token
    /// @param wrapper Address of the wrapper token
    /// @return balance Insurance pool balance
    function getInsurancePool(address wrapper) external view returns (uint256);
    
    // ============ Constants ============
    
    /// @notice Duration of each round in seconds (configurable per vault)
    function ROUND_DURATION() external view returns (uint256);
    
    /// @notice Precision for score calculations (10000 = 100%)
    function SCORE_PRECISION() external view returns (uint256);
    
    /// @notice Minimum health factor threshold (9500 = 95%)
    function HEALTH_FACTOR_THRESHOLD() external view returns (uint256);
    
    /// @notice Penalty rate for health factor violations (2000 = 20%)
    function PENALTY_RATE() external view returns (uint256);
}