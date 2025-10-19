// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/ICulfiraToken.sol";
import "./VaultStokvel.sol";
import "./utils/Constants.sol";
import "./utils/Errors.sol";

contract CulfiraManager is IVaultManager, Ownable, ReentrancyGuard {
    // --- State ---
    ICulfiraToken public immutable culToken;
    address private _treasury;
    
    ProtocolParams private _params;
    
    mapping(uint256 => VaultInfo) private _vaults;
    uint256 private _vaultCount;
    
    uint256 private _totalProtocolFees;
    
    // --- Constructor ---
    constructor(
        address culToken_,
        address treasury_
    ) Ownable(msg.sender) {
        if (culToken_ == address(0) || treasury_ == address(0)) {
            revert Errors.InvalidAddress();
        }
        
        culToken = ICulfiraToken(culToken_);
        _treasury = treasury_;
        
        _params = ProtocolParams({
            minStake: Constants.MIN_STAKE,
            roundDuration: Constants.ROUND_DURATION,
            protocolFee: Constants.DEFAULT_PROTOCOL_FEE,
            penaltyRate: Constants.DEFAULT_PENALTY_RATE
        });
    }
    
    // --- Vault Management ---
    function createVault(string memory name) external onlyOwner returns (address) {
        VaultStokvel newVault = new VaultStokvel(
            address(culToken),
            address(this)
        );
        
        _vaults[_vaultCount] = VaultInfo({
            vaultAddress: address(newVault),
            name: name,
            isActive: true,
            createdAt: block.timestamp
        });
        
        // Register vault in token
        culToken.registerVault(address(newVault), true);
        
        emit VaultCreated(_vaultCount, address(newVault), name);
        
        _vaultCount++;
        return address(newVault);
    }
    
    function setVaultStatus(uint256 vaultId, bool status) external onlyOwner {
        if (vaultId >= _vaultCount) revert Errors.InvalidVaultId();
        
        _vaults[vaultId].isActive = status;
        culToken.registerVault(_vaults[vaultId].vaultAddress, status);
        
        emit VaultStatusUpdated(vaultId, status);
    }
    
    function getVaultInfo(uint256 vaultId) external view returns (VaultInfo memory) {
        if (vaultId >= _vaultCount) revert Errors.InvalidVaultId();
        return _vaults[vaultId];
    }
    
    function getAllVaults() external view returns (VaultInfo[] memory) {
        VaultInfo[] memory allVaults = new VaultInfo[](_vaultCount);
        for (uint256 i = 0; i < _vaultCount; i++) {
            allVaults[i] = _vaults[i];
        }
        return allVaults;
    }
    
    function vaultCount() external view returns (uint256) {
        return _vaultCount;
    }
    
    // --- Protocol Configuration ---
    function updateProtocolParams(
        uint256 minStake,
        uint256 roundDuration,
        uint256 protocolFee,
        uint256 penaltyRate
    ) external onlyOwner {
        if (protocolFee > Constants.MAX_PROTOCOL_FEE) {
            revert Errors.FeeTooHigh();
        }
        if (penaltyRate > Constants.MAX_PENALTY_RATE) {
            revert Errors.PenaltyTooHigh();
        }
        
        _params = ProtocolParams({
            minStake: minStake,
            roundDuration: roundDuration,
            protocolFee: protocolFee,
            penaltyRate: penaltyRate
        });
        
        emit ProtocolParamsUpdated(minStake, roundDuration, protocolFee, penaltyRate);
    }
    
    function getProtocolParams() external view returns (ProtocolParams memory) {
        return _params;
    }
    
    // --- Fee Management ---
    function collectFees(uint256 amount) external nonReentrant {
        bool isAuthorized = msg.sender == owner();
        
        if (!isAuthorized) {
            for (uint256 i = 0; i < _vaultCount; i++) {
                if (_vaults[i].vaultAddress == msg.sender && _vaults[i].isActive) {
                    isAuthorized = true;
                    break;
                }
            }
        }
        
        if (!isAuthorized) revert Errors.Unauthorized();
        
        _totalProtocolFees += amount;
        emit FeesCollected(amount);
    }
    
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = _totalProtocolFees;
        if (amount == 0) revert Errors.NoFeesToWithdraw();
        
        _totalProtocolFees = 0;
        
        if (!culToken.transfer(_treasury, amount)) {
            revert Errors.TransferFailed();
        }
        
        emit FeesWithdrawn(amount);
    }
    
    function totalProtocolFees() external view returns (uint256) {
        return _totalProtocolFees;
    }
    
    // --- Treasury Management ---
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert Errors.InvalidTreasury();
        
        _treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
    
    function treasury() external view returns (address) {
        return _treasury;
    }
}