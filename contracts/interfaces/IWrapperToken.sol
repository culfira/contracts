// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IWrapperToken - Interface for ERC20 wrapper tokens
/// @notice Interface for wrapper tokens that restrict transfer when locked in vaults
interface IWrapperToken is IERC20 {
    
    // ============ Events ============
    
    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);
    event TokensLocked(address indexed user, address indexed vault, uint256 amount);
    event TokensUnlocked(address indexed user, address indexed vault, uint256 amount);
    event VaultAuthorized(address indexed vault);
    event VaultRevoked(address indexed vault);
    
    // ============ Errors ============
    
    error InsufficientFreeBalance();
    error UnauthorizedVault();
    error InvalidAmount();
    error TransferNotAllowed();
    
    // ============ Core Wrapper Functions ============
    
    /// @notice Wrap underlying tokens to get wrapper tokens (legacy function for compatibility)
    /// @param amount Amount of underlying tokens to wrap
    function wrap(uint256 amount) external;
    
    /// @notice Unwrap wrapper tokens to get underlying tokens (legacy function for compatibility)
    /// @param amount Amount of wrapper tokens to unwrap
    function unwrap(uint256 amount) external;
    
    /// @notice Withdraw wrapper tokens and get underlying tokens
    /// @param account Account to withdraw to
    /// @param amount Amount to withdraw
    /// @return success True if withdrawal was successful
    function withdrawTo(address account, uint256 amount) external returns (bool);
    
    /// @notice Deposit underlying tokens for a specific account
    /// @param account Account to deposit for
    /// @param amount Amount to deposit
    /// @return success True if deposit was successful
    function depositFor(address account, uint256 amount) external returns (bool);
    
    // ============ Vault Management Functions ============
    
    /// @notice Lock tokens for vault participation (only authorized vaults)
    /// @param user User whose tokens to lock
    /// @param amount Amount of tokens to lock
    function lockTokens(address user, uint256 amount) external;
    
    /// @notice Unlock tokens from vault (only authorized vaults)
    /// @param user User whose tokens to unlock
    /// @param amount Amount of tokens to unlock
    function unlockTokens(address user, uint256 amount) external;
    
    /// @notice Authorize a vault to lock/unlock tokens
    /// @param vault Vault address to authorize
    function authorizeVault(address vault) external;
    
    /// @notice Revoke vault authorization
    /// @param vault Vault address to revoke
    function revokeVault(address vault) external;
    
    // ============ View Functions ============
    
    /// @notice Get free (unlocked) balance of user
    /// @param user User address
    /// @return freeBalance Amount of free tokens
    function freeBalanceOf(address user) external view returns (uint256);
    
    /// @notice Get locked balance in specific vault
    /// @param user User address
    /// @param vault Vault address
    /// @return lockedAmount Amount of tokens locked in vault
    function getLockedBalance(address user, address vault) external view returns (uint256);
    
    /// @notice Check if vault is authorized
    /// @param vault Vault address to check
    /// @return authorized True if vault is authorized
    function authorizedVaults(address vault) external view returns (bool);
    
    /// @notice Get total locked amount for user
    /// @param user User address
    /// @return totalLocked Total amount of locked tokens
    function totalLocked(address user) external view returns (uint256);
    
    /// @notice Get locked balances for user in specific vault
    /// @param user User address
    /// @param vault Vault address
    /// @return lockedAmount Amount locked in vault
    function lockedBalances(address user, address vault) external view returns (uint256);
}