// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./WrapperToken.sol";

/// @title InsuranceManager - Manages insurance pool and distributions
/// @notice Collects penalties and distributes rewards based on member scores
contract InsuranceManager is Ownable, ReentrancyGuard {
    
    // ============ Structs ============
    
    struct MemberScore {
        uint256 totalScore;        // Accumulated score
        uint256 roundsCompleted;   // Number of rounds completed
        uint256 violationCount;    // Number of violations
        uint256 lastUpdateRound;   // Last round score was updated
    }
    
    struct DistributionRecord {
        uint256 roundId;
        address member;
        address token;
        uint256 amount;
        uint256 timestamp;
    }
    
    // ============ State Variables ============
    
    /// @dev Insurance pool: token => amount
    mapping(address => uint256) public insurancePool;
    
    /// @dev Member scores: member => score data
    mapping(address => MemberScore) public memberScores;
    
    /// @dev Distribution history
    DistributionRecord[] public distributions;
    
    /// @dev Registered vaults that can contribute to insurance
    mapping(address => bool) public registeredVaults;
    
    // ============ Constants ============
    
    uint256 public constant INITIAL_SCORE = 10000;  // 100%
    uint256 public constant MAX_SCORE = 15000;      // 150% (bonus for good behavior)
    uint256 public constant VIOLATION_PENALTY = 2000; // 20% reduction per violation
    uint256 public constant COMPLETION_BONUS = 100;   // 1% bonus per successful round
    
    // ============ Events ============
    
    event InsuranceDeposited(address indexed vault, address indexed token, uint256 amount);
    event InsuranceDistributed(
        uint256 indexed roundId,
        address indexed member,
        address indexed token,
        uint256 amount
    );
    event ScoreUpdated(address indexed member, uint256 newScore, string reason);
    event VaultRegistered(address indexed vault);
    
    // ============ Errors ============
    
    error UnauthorizedVault();
    error InvalidAmount();
    error InsufficientPoolBalance();
    error NoEligibleMembers();
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {}
    
    // ============ Admin Functions ============
    
    /// @notice Register a vault to contribute to insurance
    function registerVault(address vault) external onlyOwner {
        registeredVaults[vault] = true;
        emit VaultRegistered(vault);
    }
    
    // ============ Vault Functions ============
    
    /// @notice Deposit penalty to insurance pool
    function depositToInsurance(
        address token,
        uint256 amount
    ) external nonReentrant {
        if (!registeredVaults[msg.sender]) revert UnauthorizedVault();
        if (amount == 0) revert InvalidAmount();
        
        WrapperToken(token).transferFrom(msg.sender, address(this), amount);
        insurancePool[token] += amount;
        
        emit InsuranceDeposited(msg.sender, token, amount);
    }
    
    // ============ Score Management ============
    
    /// @notice Initialize member score
    function initializeMember(address member) external {
        if (!registeredVaults[msg.sender]) revert UnauthorizedVault();
        
        if (memberScores[member].totalScore == 0) {
            memberScores[member] = MemberScore({
                totalScore: INITIAL_SCORE,
                roundsCompleted: 0,
                violationCount: 0,
                lastUpdateRound: 0
            });
        }
    }
    
    /// @notice Update member score after round completion
    function updateScoreOnCompletion(
        address member,
        uint256 roundId,
        bool hadViolation
    ) external {
        if (!registeredVaults[msg.sender]) revert UnauthorizedVault();
        
        MemberScore storage score = memberScores[member];
        
        if (hadViolation) {
            // Apply penalty
            if (score.totalScore > VIOLATION_PENALTY) {
                score.totalScore -= VIOLATION_PENALTY;
            } else {
                score.totalScore = 0;
            }
            score.violationCount++;
            
            emit ScoreUpdated(member, score.totalScore, "Violation penalty");
        } else {
            // Apply bonus for clean round
            if (score.totalScore < MAX_SCORE) {
                score.totalScore += COMPLETION_BONUS;
                if (score.totalScore > MAX_SCORE) {
                    score.totalScore = MAX_SCORE;
                }
            }
            
            emit ScoreUpdated(member, score.totalScore, "Completion bonus");
        }
        
        score.roundsCompleted++;
        score.lastUpdateRound = roundId;
    }
    
    // ============ Distribution Functions ============
    
    /// @notice Distribute insurance pool to eligible members
    function distributeInsurance(
        uint256 roundId,
        address[] calldata members,
        address[] calldata tokens
    ) external onlyOwner nonReentrant {
        if (members.length == 0) revert NoEligibleMembers();
        
        // Calculate total scores
        uint256 totalScore = 0;
        for (uint256 i = 0; i < members.length; i++) {
            totalScore += memberScores[members[i]].totalScore;
        }
        
        if (totalScore == 0) revert NoEligibleMembers();
        
        // Distribute each token
        for (uint256 t = 0; t < tokens.length; t++) {
            address token = tokens[t];
            uint256 poolAmount = insurancePool[token];
            
            if (poolAmount == 0) continue;
            
            // Distribute proportionally based on scores
            for (uint256 m = 0; m < members.length; m++) {
                address member = members[m];
                uint256 memberScore = memberScores[member].totalScore;
                
                if (memberScore > 0) {
                    uint256 share = (poolAmount * memberScore) / totalScore;
                    
                    if (share > 0) {
                        WrapperToken(token).transfer(member, share);
                        
                        // Record distribution
                        distributions.push(DistributionRecord({
                            roundId: roundId,
                            member: member,
                            token: token,
                            amount: share,
                            timestamp: block.timestamp
                        }));
                        
                        emit InsuranceDistributed(roundId, member, token, share);
                    }
                }
            }
            
            // Clear pool for this token
            insurancePool[token] = 0;
        }
    }
    
    // ============ View Functions ============
    
    /// @notice Get member score info
    function getMemberScore(address member) external view returns (MemberScore memory) {
        return memberScores[member];
    }
    
    /// @notice Get insurance pool balance for token
    function getPoolBalance(address token) external view returns (uint256) {
        return insurancePool[token];
    }
    
    /// @notice Get distribution history
    function getDistributions() external view returns (DistributionRecord[] memory) {
        return distributions;
    }
    
    /// @notice Get distribution count
    function getDistributionCount() external view returns (uint256) {
        return distributions.length;
    }
    
    /// @notice Calculate potential distribution for member
    function calculatePotentialShare(
        address member,
        address token,
        address[] calldata allMembers
    ) external view returns (uint256) {
        uint256 memberScore = memberScores[member].totalScore;
        if (memberScore == 0) return 0;
        
        uint256 totalScore = 0;
        for (uint256 i = 0; i < allMembers.length; i++) {
            totalScore += memberScores[allMembers[i]].totalScore;
        }
        
        if (totalScore == 0) return 0;
        
        uint256 poolAmount = insurancePool[token];
        return (poolAmount * memberScore) / totalScore;
    }
}