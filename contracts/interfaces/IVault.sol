// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IVault {
    // --- Enums ---
    enum RoundState {
        DEPOSIT,
        ACTIVE,
        PAYOUT,
        COMPLETED
    }

    // --- Structs ---
    struct Member {
        uint256 stakedAmount;
        uint256 position;
        uint256 joinedRound;
        bool hasReceivedPayout;
        bool isActive;
    }

    struct Round {
        uint256 id;
        uint256 totalStaked;
        uint256 startTime;
        uint256 endTime;
        uint256 cycleDuration; // Added: duration for this specific round
        address recipient;
        RoundState state;
    }

    struct Debt {
        uint256 amount;
        uint256 initialValue;
        uint256 deadline;
        bool isActive;
    }

    // --- Events ---
    event MemberJoined(address indexed user, uint256 amount, uint256 position);
    event MemberExited(address indexed user, uint256 amount);
    event RoundStarted(
        uint256 indexed roundId,
        uint256 totalStaked,
        uint256 cycleDuration
    );
    event RoundCompleted(uint256 indexed roundId);
    event PayoutClaimed(
        address indexed recipient,
        uint256 amount,
        uint256 roundId
    );
    event DebtRepaid(address indexed user, uint256 amount, uint256 roundId);
    event MarginCall(
        address indexed user,
        uint256 healthFactor,
        string severity
    );
    event Liquidated(address indexed user, uint256 deficit, uint256 penalty);

    // --- Core Functions ---
    function joinVault(uint256 amount) external;

    function exitVault() external;

    function startRound() external;

    function startRoundWithDuration(uint256 customDuration) external;

    function claimRoundCUL() external;

    function repayDebt() external;

    function completeRound() external;

    // --- Risk Management ---
    function checkHealthFactor(address user) external view returns (uint256);

    function enforceHealthFactor(address user) external;

    function liquidate(address user) external;

    function topUpCUL(uint256 amount) external;

    // --- View Functions ---
    function getNextRecipient() external view returns (address);

    function getCurrentRound() external view returns (Round memory);

    function getRoundInfo(uint256 roundId) external view returns (Round memory);

    function getMemberInfo(address user) external view returns (Member memory);

    function getDebtInfo(address user) external view returns (Debt memory);

    function totalMembers() external view returns (uint256);

    function totalStaked() external view returns (uint256);

    function currentRound() external view returns (uint256);
}
