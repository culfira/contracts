// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WrapperToken.sol";
import "./libraries/WeightedPoolLib.sol";

/// @title MultiAssetVault - Multi-asset stokvel vault with weighted pools
contract MultiAssetVault is ReentrancyGuard, Ownable {
    
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
    
    // ============ State Variables ============
    
    uint256 private currentRoundId;
    uint256 private totalMembers;
    
    mapping(uint256 => Round) private rounds;
    mapping(address => Member) private members;
    mapping(address => mapping(uint256 => uint256)) private memberDeposits; // member => (assetIndex => amount)
    
    address[] private memberList;
    address[] private registeredWrappers;
    mapping(address => bool) private isWrapperRegistered;
    
    /// @dev Insurance pool balances per asset
    mapping(address => uint256) private insurancePool;
    
    /// @dev Health factor tracking
    mapping(address => uint256) private healthFactors;
    
    // ============ Constants ============
    
    uint256 public constant ROUND_DURATION = 30 days;
    uint256 public constant SCORE_PRECISION = 10000;
    uint256 public constant HEALTH_FACTOR_THRESHOLD = 9500; // 95%
    uint256 public constant PENALTY_RATE = 2000; // 20%
    
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
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {
        currentRoundId = 1;
    }
    
    // ============ Admin Functions ============
    
    /// @notice Register a wrapper token for use in vault
    function registerWrapper(address wrapper) external onlyOwner {
        if (!isWrapperRegistered[wrapper]) {
            registeredWrappers.push(wrapper);
            isWrapperRegistered[wrapper] = true;
            emit WrapperRegistered(wrapper);
        }
    }
    
    // ============ Member Functions ============
    
    /// @notice Join vault by depositing multi-asset
    /// @param wrappers Array of wrapper token addresses
    /// @param amounts Array of amounts to deposit
    /// @param weights Array of weights (must sum to 10000)
    function joinVault(
        address[] calldata wrappers,
        uint256[] calldata amounts,
        uint256[] calldata weights
    ) external nonReentrant {
        if (members[msg.sender].isActive) revert AlreadyMember();
        if (wrappers.length != amounts.length || amounts.length != weights.length) {
            revert InvalidAmount();
        }
        
        // Convert weights to WeightedPoolLib precision and validate
        uint256[] memory libWeights = new uint256[](weights.length);
        for (uint256 i = 0; i < weights.length; i++) {
            libWeights[i] = (weights[i] * WeightedPoolLib.PRECISION) / SCORE_PRECISION;
        }
        
        if (!WeightedPoolLib.validateWeights(libWeights)) {
            revert InvalidAssetRatio();
        }
        
        uint256 totalValue = 0;
        
        // Deposit assets and lock in wrappers
        for (uint256 i = 0; i < wrappers.length; i++) {
            if (!isWrapperRegistered[wrappers[i]]) revert InvalidAmount();
            
            WrapperToken wrapper = WrapperToken(wrappers[i]);
            wrapper.transferFrom(msg.sender, address(this), amounts[i]);
            wrapper.lockTokens(msg.sender, amounts[i]);
            
            memberDeposits[msg.sender][i] = amounts[i];
            
            // Calculate weighted value contribution
            totalValue += (amounts[i] * weights[i]) / SCORE_PRECISION;
            
            emit AssetDeposited(msg.sender, wrappers[i], amounts[i]);
        }
        
        // Register member
        members[msg.sender] = Member({
            depositedAmounts: totalValue, // Now properly calculated
            position: totalMembers,
            joinedRound: currentRoundId,
            score: SCORE_PRECISION,
            hasReceivedPayout: false,
            isActive: true
        });
        
        memberList.push(msg.sender);
        totalMembers++;
        
        emit MemberJoined(msg.sender, totalMembers - 1);
    }
    
    // ============ Round Management ============
    
    /// @notice Start a new round with pool assets
    function startRound(
        address[] calldata wrappers,
        uint256[] calldata weights
    ) external onlyOwner {
        if (currentRoundId > 1) {
            if (rounds[currentRoundId - 1].state != RoundState.COMPLETED) {
                revert RoundNotActive();
            }
        }
        
        address winner = getNextRecipient();
        if (winner == address(0)) revert NotMember();
        
        Round storage round = rounds[currentRoundId];
        round.id = currentRoundId;
        round.startTime = block.timestamp;
        round.endTime = block.timestamp + ROUND_DURATION;
        round.winner = winner;
        round.state = RoundState.ACTIVE;
        
        // Initialize pool assets with current balances
        for (uint256 i = 0; i < wrappers.length; i++) {
            uint256 balance = WrapperToken(wrappers[i]).balanceOf(address(this));
            
            round.poolAssets.push(PoolAsset({
                wrapperToken: wrappers[i],
                weight: weights[i],
                initialAmount: balance,
                currentAmount: balance
            }));
        }
        
        emit RoundStarted(currentRoundId, winner);
    }
    
    /// @notice Winner claims all pool assets to their wallet
    function claimWinnerAssets() external nonReentrant {
        Round storage round = rounds[currentRoundId];
        
        if (round.state != RoundState.ACTIVE) revert RoundNotActive();
        if (round.winner != msg.sender) revert NotWinner();
        if (members[msg.sender].hasReceivedPayout) revert AlreadyMember();
        
        // Transfer ALL pool assets to winner's wallet
        for (uint256 i = 0; i < round.poolAssets.length; i++) {
            PoolAsset storage asset = round.poolAssets[i];
            WrapperToken wrapperToken = WrapperToken(asset.wrapperToken);
            
            // Transfer all pool assets to winner
            if (asset.currentAmount > 0) {
                wrapperToken.transfer(msg.sender, asset.currentAmount);
            }
        }
        
        members[msg.sender].hasReceivedPayout = true;
        
        emit WinnerClaimed(msg.sender, currentRoundId);
    }
    

    
    /// @notice Complete round - winner must return assets for health check
    function completeRound() external onlyOwner {
        Round storage round = rounds[currentRoundId];
        
        if (round.state != RoundState.ACTIVE) revert RoundNotActive();
        if (block.timestamp < round.endTime) revert RoundNotActive();
        
        // Calculate health factors based on winner's wallet balance
        _calculateHealthFactors(currentRoundId);
        
        // Winner must return remaining assets to vault for next round
        address winner = round.winner;
        for (uint256 i = 0; i < round.poolAssets.length; i++) {
            PoolAsset storage asset = round.poolAssets[i];
            WrapperToken wrapperToken = WrapperToken(asset.wrapperToken);
            
            uint256 winnerBalance = wrapperToken.balanceOf(winner);
            if (winnerBalance > 0) {
                // Transfer remaining assets back to vault for next round
                wrapperToken.transferFrom(winner, address(this), winnerBalance);
            }
        }
        
        round.state = RoundState.COMPLETED;
        members[round.winner].hasReceivedPayout = true;
        
        currentRoundId++;
        
        emit RoundCompleted(currentRoundId - 1);
    }
    
    // ============ Health Factor Management ============
    
    /// @notice Calculate health factor for round winner using WeightedPoolLib
    function _calculateHealthFactors(uint256 roundId) internal {
        Round storage round = rounds[roundId];
        address winner = round.winner;
        
        // Prepare arrays for WeightedPoolLib
        uint256[] memory initialBalances = new uint256[](round.poolAssets.length);
        uint256[] memory currentBalances = new uint256[](round.poolAssets.length);
        uint256[] memory weights = new uint256[](round.poolAssets.length);
        
        uint256 totalDeficit = 0;
        
        for (uint256 i = 0; i < round.poolAssets.length; i++) {
            PoolAsset storage asset = round.poolAssets[i];
            
            initialBalances[i] = asset.initialAmount;
            // Check winner's wallet balance, not vault balance
            currentBalances[i] = WrapperToken(asset.wrapperToken).balanceOf(winner);
            weights[i] = (asset.weight * WeightedPoolLib.PRECISION) / SCORE_PRECISION; // Convert to lib precision
            
            // Update current amount in storage
            asset.currentAmount = currentBalances[i];
            
            // Calculate deficit based on winner's balance
            if (currentBalances[i] < initialBalances[i]) {
                totalDeficit += initialBalances[i] - currentBalances[i];
            }
        }
        
        // Use WeightedPoolLib to calculate health factor
        uint256 healthFactor = WeightedPoolLib.calculateHealthFactor(
            initialBalances,
            currentBalances,
            weights
        );
        
        // Convert back to our precision
        healthFactor = (healthFactor * SCORE_PRECISION) / WeightedPoolLib.PRECISION;
        healthFactors[winner] = healthFactor;
        
        // Apply penalty if health factor is too low
        if (healthFactor < HEALTH_FACTOR_THRESHOLD) {
            uint256 penalty = (totalDeficit * PENALTY_RATE) / SCORE_PRECISION;
            
            // Distribute penalty to insurance pool proportionally
            for (uint256 i = 0; i < round.poolAssets.length; i++) {
                address wrapper = round.poolAssets[i].wrapperToken;
                uint256 assetPenalty = (penalty * weights[i]) / WeightedPoolLib.PRECISION;
                insurancePool[wrapper] += assetPenalty;
            }
            
            // Reduce member score
            uint256 scoreReduction = SCORE_PRECISION - healthFactor;
            if (members[winner].score > scoreReduction) {
                members[winner].score -= scoreReduction;
            } else {
                members[winner].score = 0;
            }
            
            emit HealthFactorViolation(winner, totalDeficit);
        }
    }
    
    /// @notice Distribute insurance pool at end of cycle
    function distributeInsurance() external onlyOwner {
        uint256 totalScore;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (members[memberList[i]].isActive) {
                totalScore += members[memberList[i]].score;
            }
        }
        
        if (totalScore == 0) return;
        
        for (uint256 i = 0; i < registeredWrappers.length; i++) {
            address wrapper = registeredWrappers[i];
            uint256 poolAmount = insurancePool[wrapper];
            
            if (poolAmount > 0) {
                for (uint256 j = 0; j < memberList.length; j++) {
                    address member = memberList[j];
                    if (members[member].isActive) {
                        uint256 share = (poolAmount * members[member].score) / totalScore;
                        
                        WrapperToken(wrapper).transfer(member, share);
                        
                        emit InsuranceDistributed(member, share);
                    }
                }
                
                insurancePool[wrapper] = 0;
            }
        }
    }
    
    // ============ View Functions ============
    
    /// @notice Get next round recipient
    function getNextRecipient() public view returns (address) {
        for (uint256 i = 0; i < memberList.length; i++) {
            address member = memberList[i];
            if (members[member].isActive && !members[member].hasReceivedPayout) {
                return member;
            }
        }
        return address(0);
    }
    
    /// @notice Get member info
    function getMemberInfo(address user) external view returns (Member memory) {
        return members[user];
    }
    
    /// @notice Get round info
    function getRoundInfo(uint256 roundId) external view returns (Round memory) {
        return rounds[roundId];
    }
    
    /// @notice Get health factor for user
    function getHealthFactor(address user) external view returns (uint256) {
        return healthFactors[user];
    }
    
    /// @notice Get insurance pool balance
    function getInsurancePool(address wrapper) external view returns (uint256) {
        return insurancePool[wrapper];
    }
}