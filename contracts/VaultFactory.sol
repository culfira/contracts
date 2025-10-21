// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MultiAssetVault.sol";
import "./WrapperRegistry.sol";
import "./InsuranceManager.sol";
import "./interfaces/IVaultFactory.sol";

/// @title VaultFactory - Factory for creating MultiAssetVaults
/// @notice Manages creation and registration of vaults
contract VaultFactory is Ownable, IVaultFactory {
    
    // ============ State Variables ============
    
    WrapperRegistry public immutable wrapperRegistry;
    InsuranceManager public immutable insuranceManager;
    
    address[] public vaults;
    mapping(address => bool) public isVault;
    mapping(address => VaultMetadata) public vaultMetadata;
    
    // ============ Constructor ============
    
    constructor(
        address wrapperRegistry_,
        address insuranceManager_
    ) Ownable(msg.sender) {
        wrapperRegistry = WrapperRegistry(wrapperRegistry_);
        insuranceManager = InsuranceManager(insuranceManager_);
    }
    
    // ============ Functions ============
    
    /// @notice Create a new MultiAssetVault
    /// @param name Name of the vault
    /// @param description Description of the vault
    /// @param cycleTime Duration of each round in seconds (minimum 1 day)
    function createVault(
        string memory name,
        string memory description,
        uint256 cycleTime
    ) external returns (address) {
        require(cycleTime >= 1 days, "Cycle time too short");
        require(cycleTime <= 365 days, "Cycle time too long");
        
        MultiAssetVault vault = new MultiAssetVault(cycleTime);
        
        address vaultAddress = address(vault);
        vaults.push(vaultAddress);
        isVault[vaultAddress] = true;
        
        vaultMetadata[vaultAddress] = VaultMetadata({
            name: name,
            description: description,
            creator: msg.sender,
            createdAt: block.timestamp,
            cycleTime: cycleTime,
            isActive: true
        });
        
        // Register vault in insurance manager (if we own it)
        // insuranceManager.registerVault(vaultAddress);
        
        // Transfer ownership to creator
        vault.transferOwnership(msg.sender);
        
        emit VaultCreated(vaultAddress, msg.sender, name, cycleTime);
        
        return vaultAddress;
    }
    
    /// @notice Deactivate a vault
    function deactivateVault(address vault) external onlyOwner {
        require(isVault[vault], "Not a vault");
        vaultMetadata[vault].isActive = false;
        emit VaultDeactivated(vault);
    }
    
    /// @notice Get all vaults
    function getAllVaults() external view returns (address[] memory) {
        return vaults;
    }
    
    /// @notice Get vault count
    function getVaultCount() external view returns (uint256) {
        return vaults.length;
    }
    
    /// @notice Get vault cycle time
    function getVaultCycleTime(address vault) external view returns (uint256) {
        require(isVault[vault], "Not a vault");
        return vaultMetadata[vault].cycleTime;
    }
    
    /// @notice Get active vaults
    function getActiveVaults() external view returns (address[] memory) {
        uint256 activeCount = 0;
        
        // Count active vaults
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaultMetadata[vaults[i]].isActive) {
                activeCount++;
            }
        }
        
        // Build array
        address[] memory activeVaults = new address[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaultMetadata[vaults[i]].isActive) {
                activeVaults[index] = vaults[i];
                index++;
            }
        }
        
        return activeVaults;
    }
}