// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICulfiraToken is IERC20 {
    // --- Events ---
    event VaultRegistered(address indexed vault, bool status);
    event TokensLocked(address indexed user, uint256 amount);
    event TokensUnlocked(address indexed user, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    
    // --- Vault Management ---
    function registerVault(address vault, bool status) external;
    function isVault(address vault) external view returns (bool);
    
    // --- Lock Mechanism ---
    function lock(address user, uint256 amount) external;
    function unlock(address user, uint256 amount) external;
    function lockedBalance(address user) external view returns (uint256);
    function availableBalance(address user) external view returns (uint256);
    
    // --- Mint/Treasury ---
    function mint(address to, uint256 amount) external payable;
    function treasury() external view returns (address);
    function setTreasury(address newTreasury) external;
}