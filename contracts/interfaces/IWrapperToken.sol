// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IWrapperToken
 * @notice Interface for ERC20 wrapper tokens that represent underlying assets in Culfira protocol
 * @dev Extends ERC20 with wrapper-specific functionality for vault interactions and yield farming
 */
interface IWrapperToken is IERC20 {
    // --- Events ---
    event Wrapped(address indexed user, uint256 underlyingAmount, uint256 wrapperAmount);
    event Unwrapped(address indexed user, uint256 wrapperAmount, uint256 underlyingAmount);
    event VaultLocked(address indexed vault, address indexed user, uint256 amount);
    event VaultUnlocked(address indexed vault, address indexed user, uint256 amount);
    event YieldFarmingEnabled(address indexed user, uint256 amount);
    event YieldFarmingDisabled(address indexed user, uint256 amount);
    
    // --- Core Wrapper Functions ---
    /**
     * @notice Wrap underlying token to receive wrapper token
     * @param amount Amount of underlying token to wrap
     * @return wrapperAmount Amount of wrapper token minted
     */
    function wrap(uint256 amount) external returns (uint256 wrapperAmount);
    
    /**
     * @notice Unwrap wrapper token to receive underlying token
     * @param amount Amount of wrapper token to unwrap
     * @return underlyingAmount Amount of underlying token returned
     */
    function unwrap(uint256 amount) external returns (uint256 underlyingAmount);
    
    // --- Vault Management ---
    /**
     * @notice Lock wrapper tokens for vault participation (only registered vaults)
     * @param user User whose tokens to lock
     * @param amount Amount to lock
     */
    function lockForVault(address user, uint256 amount) external;
    
    /**
     * @notice Unlock wrapper tokens from vault participation
     * @param user User whose tokens to unlock
     * @param amount Amount to unlock
     */
    function unlockFromVault(address user, uint256 amount) external;
    
    /**
     * @notice Enable yield farming mode (restricts transfers but allows farming)
     * @param user User to enable yield farming for
     * @param amount Amount to enable for farming
     */
    function enableYieldFarming(address user, uint256 amount) external;
    
    /**
     * @notice Disable yield farming mode
     * @param user User to disable yield farming for
     * @param amount Amount to disable from farming
     */
    function disableYieldFarming(address user, uint256 amount) external;
    
    // --- Registry Functions ---
    /**
     * @notice Register/unregister a vault (only registry)
     * @param vault Vault address
     * @param status Registration status
     */
    function registerVault(address vault, bool status) external;
    
    /**
     * @notice Check if address is registered vault
     * @param vault Address to check
     * @return True if registered vault
     */
    function isVault(address vault) external view returns (bool);
    
    // --- View Functions ---
    /**
     * @notice Get underlying token address
     * @return Address of underlying token
     */
    function underlyingToken() external view returns (address);
    
    /**
     * @notice Get user's locked balance for vaults
     * @param user User address
     * @return Locked balance
     */
    function vaultLockedBalance(address user) external view returns (uint256);
    
    /**
     * @notice Get user's yield farming balance
     * @param user User address
     * @return Yield farming balance
     */
    function yieldFarmingBalance(address user) external view returns (uint256);
    
    /**
     * @notice Get user's freely transferable balance
     * @param user User address
     * @return Free balance (total - vault_locked - yield_farming)
     */
    function freeBalance(address user) external view returns (uint256);
    
    /**
     * @notice Get total wrapped supply
     * @return Total supply of wrapper tokens
     */
    function totalWrapped() external view returns (uint256);
    
    /**
     * @notice Get conversion rate from underlying to wrapper
     * @return rate Exchange rate (underlying to wrapper)
     */
    function getWrapRate() external view returns (uint256 rate);
    
    /**
     * @notice Get conversion rate from wrapper to underlying
     * @return rate Exchange rate (wrapper to underlying)
     */
    function getUnwrapRate() external view returns (uint256 rate);
}