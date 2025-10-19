// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IYieldStrategy {
    // --- Events ---
    event Deposited(uint256 amount);
    event Withdrawn(uint256 amount);
    event RewardsClaimed(uint256 amount);
    
    // --- Core Functions ---
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimRewards() external returns (uint256);
    function compound() external;
    
    // --- View Functions ---
    function getBalance() external view returns (uint256);
    function getPendingRewards() external view returns (uint256);
    function getAPY() external view returns (uint256);
}