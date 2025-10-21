// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IWrapperToken.sol";

/// @title WrapperToken - ERC20 wrapper for underlying tokens
/// @notice Wrapper token that restricts transfer when locked in vaults
contract WrapperToken is ERC20Wrapper, Ownable, ReentrancyGuard, IWrapperToken {
    
    // ============ State Variables ============
    
    /// @dev Vault contract addresses that can lock tokens
    mapping(address => bool) public authorizedVaults;
    
    /// @dev Amount of tokens locked per user per vault
    mapping(address => mapping(address => uint256)) public lockedBalances;
    
    /// @dev Total locked amount per user
    mapping(address => uint256) public totalLocked;
    
    // ============ Constructor ============
    
    constructor(
        IERC20 underlyingToken_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Wrapper(underlyingToken_) Ownable(msg.sender) {}
    
    // ============ External Functions ============
    
    /// @notice Wrap underlying tokens to get wrapper tokens (legacy function for compatibility)
    function wrap(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        depositFor(msg.sender, amount);
        emit Wrapped(msg.sender, amount);
    }
    
    /// @notice Unwrap wrapper tokens to get underlying tokens (legacy function for compatibility)
    function unwrap(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        
        uint256 freeBalance = balanceOf(msg.sender) - totalLocked[msg.sender];
        if (freeBalance < amount) revert InsufficientFreeBalance();
        
        withdrawTo(msg.sender, amount);
        emit Unwrapped(msg.sender, amount);
    }
    
    /// @notice Override withdrawTo to check locked balances
    function withdrawTo(address account, uint256 amount) public override(ERC20Wrapper, IWrapperToken) returns (bool) {
        uint256 freeBalance = balanceOf(_msgSender()) - totalLocked[_msgSender()];
        if (freeBalance < amount) revert InsufficientFreeBalance();
        
        return super.withdrawTo(account, amount);
    }
    
    /// @notice Override depositFor to maintain interface compatibility
    function depositFor(address account, uint256 amount) public override(ERC20Wrapper, IWrapperToken) returns (bool) {
        return super.depositFor(account, amount);
    }
    
    /// @notice Lock tokens for vault participation (only authorized vaults)
    function lockTokens(address user, uint256 amount) external {
        if (!authorizedVaults[msg.sender]) revert UnauthorizedVault();
        if (amount == 0) revert InvalidAmount();
        
        // Check if user has enough total balance (not just free balance)
        if (balanceOf(user) < totalLocked[user] + amount) {
            revert InsufficientFreeBalance();
        }
        
        lockedBalances[user][msg.sender] += amount;
        totalLocked[user] += amount;
        
        emit TokensLocked(user, msg.sender, amount);
    }
    
    /// @notice Unlock tokens from vault (only authorized vaults)
    function unlockTokens(address user, uint256 amount) external {
        if (!authorizedVaults[msg.sender]) revert UnauthorizedVault();
        if (amount == 0) revert InvalidAmount();
        
        if (lockedBalances[user][msg.sender] < amount) revert InvalidAmount();
        
        lockedBalances[user][msg.sender] -= amount;
        totalLocked[user] -= amount;
        
        emit TokensUnlocked(user, msg.sender, amount);
    }
    
    /// @notice Authorize a vault to lock/unlock tokens
    function authorizeVault(address vault) external onlyOwner {
        authorizedVaults[vault] = true;
        emit VaultAuthorized(vault);
    }
    
    /// @notice Revoke vault authorization
    function revokeVault(address vault) external onlyOwner {
        authorizedVaults[vault] = false;
        emit VaultRevoked(vault);
    }
    
    // ============ View Functions ============
    
    /// @notice Get free (unlocked) balance of user
    function freeBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user) - totalLocked[user];
    }
    
    /// @notice Get locked balance in specific vault
    function getLockedBalance(address user, address vault) external view returns (uint256) {
        return lockedBalances[user][vault];
    }
    
    // ============ Internal Functions ============
    
    /// @dev Override transfer to prevent moving locked tokens
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 freeBalance = balanceOf(from) - totalLocked[from];
            if (freeBalance < value) revert TransferNotAllowed();
        }
        
        super._update(from, to, value);
    }
}