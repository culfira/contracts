// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICulfiraToken.sol";
import "./utils/Constants.sol";
import "./utils/Errors.sol";

contract CulfiraToken is ERC20, Ownable, ICulfiraToken {
    // --- State ---
    mapping(address => bool) private _vaults;
    mapping(address => uint256) private _lockedBalance;

    address private _treasury;

    // --- Constructor ---
    constructor(
        address treasury_
    ) ERC20("Culfira Token", "CUL") Ownable(msg.sender) {
        if (treasury_ == address(0)) revert Errors.InvalidTreasury();
        _treasury = treasury_;
    }

    // --- Admin Functions ---
    function registerVault(address vault, bool status) external onlyOwner {
        _vaults[vault] = status;
        emit VaultRegistered(vault, status);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert Errors.InvalidTreasury();
        _treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function mint(address to, uint256 amount) external payable {
        uint256 requiredHBAR = (amount * Constants.RESERVE_RATIO) / 100;
        if (msg.value < requiredHBAR) revert Errors.InsufficientHBARBacking();

        _mint(to, amount);

        (bool success, ) = _treasury.call{value: msg.value}("");
        if (!success) revert Errors.TransferFailed();
    }

    // --- Lock Mechanism ---
    function lock(address user, uint256 amount) external {
        if (!_vaults[msg.sender]) revert Errors.OnlyVaultCanLock();

        _lockedBalance[user] += amount;
        emit TokensLocked(user, amount);
    }

    function unlock(address user, uint256 amount) external {
        if (!_vaults[msg.sender]) revert Errors.OnlyVaultCanLock();
        if (_lockedBalance[user] < amount)
            revert Errors.InsufficientUnlockedBalance();

        _lockedBalance[user] -= amount;
        emit TokensUnlocked(user, amount);
    }

    // --- Hook: Transfer Restriction ---
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Allow mint/burn
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Allow vault transfers
        if (_vaults[from] || _vaults[to]) {
            super._update(from, to, amount);
            return;
        }

        if (_lockedBalance[from] > 0) {
            // User has staked tokens, they can only transfer non-staked portion
            // But since staked tokens are IN the vault, not in user wallet,
            // we just need to ensure they're not trying to manipulate state
            revert Errors.TokensLocked();
        }

        super._update(from, to, amount);
    }

    // --- View Functions ---
    function isVault(address vault) external view returns (bool) {
        return _vaults[vault];
    }

    function lockedBalance(address user) external view returns (uint256) {
        return _lockedBalance[user];
    }

    function availableBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    function treasury() external view returns (address) {
        return _treasury;
    }
}
