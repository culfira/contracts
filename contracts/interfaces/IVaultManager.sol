// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IVaultManager {
    // --- Structs ---
    struct VaultInfo {
        address vaultAddress;
        string name;
        bool isActive;
        uint256 createdAt;
    }
    
    struct ProtocolParams {
        uint256 minStake;
        uint256 roundDuration;
        uint256 protocolFee;
        uint256 penaltyRate;
    }
    
    // --- Events ---
    event VaultCreated(uint256 indexed vaultId, address indexed vaultAddress, string name);
    event VaultStatusUpdated(uint256 indexed vaultId, bool isActive);
    event ProtocolParamsUpdated(uint256 minStake, uint256 roundDuration, uint256 fee, uint256 penalty);
    event TreasuryUpdated(address indexed newTreasury);
    event FeesCollected(uint256 amount);
    event FeesWithdrawn(uint256 amount);
    
    // --- Vault Management ---
    function createVault(string memory name) external returns (address);
    function setVaultStatus(uint256 vaultId, bool status) external;
    function getVaultInfo(uint256 vaultId) external view returns (VaultInfo memory);
    function getAllVaults() external view returns (VaultInfo[] memory);
    function vaultCount() external view returns (uint256);
    
    // --- Protocol Config ---
    function updateProtocolParams(
        uint256 minStake,
        uint256 roundDuration,
        uint256 protocolFee,
        uint256 penaltyRate
    ) external;
    function getProtocolParams() external view returns (ProtocolParams memory);
    
    // --- Fee Management ---
    function collectFees(uint256 amount) external;
    function withdrawFees() external;
    function totalProtocolFees() external view returns (uint256);
    
    // --- Treasury ---
    function setTreasury(address newTreasury) external;
    function treasury() external view returns (address);
}