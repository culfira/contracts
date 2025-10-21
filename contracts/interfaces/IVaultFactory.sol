// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../WrapperRegistry.sol";
import "../InsuranceManager.sol";

/// @title IVaultFactory - Interface for VaultFactory
interface IVaultFactory {
    
    // ============ Structs ============
    
    struct VaultMetadata {
        string name;
        string description;
        address creator;
        uint256 createdAt;
        uint256 cycleTime;
        bool isActive;
    }
    
    // ============ Events ============
    
    event VaultCreated(
        address indexed vault,
        address indexed creator,
        string name,
        uint256 cycleTime
    );
    event VaultDeactivated(address indexed vault);
    
    // ============ Functions ============
    
    /// @notice Create a new MultiAssetVault with custom cycle time
    /// @param name Name of the vault
    /// @param description Description of the vault
    /// @param cycleTime Duration of each round in seconds (minimum 1 day)
    /// @return vault Address of the created vault
    function createVault(
        string memory name,
        string memory description,
        uint256 cycleTime
    ) external returns (address vault);
    
    /// @notice Deactivate a vault
    /// @param vault Address of the vault to deactivate
    function deactivateVault(address vault) external;
    
    /// @notice Get all vaults
    /// @return vaults Array of all vault addresses
    function getAllVaults() external view returns (address[] memory vaults);
    
    /// @notice Get vault count
    /// @return count Total number of vaults created
    function getVaultCount() external view returns (uint256 count);
    
    /// @notice Get vault cycle time
    /// @param vault Address of the vault
    /// @return cycleTime Duration of each round in seconds
    function getVaultCycleTime(address vault) external view returns (uint256 cycleTime);
    
    /// @notice Get active vaults
    /// @return activeVaults Array of active vault addresses
    function getActiveVaults() external view returns (address[] memory activeVaults);
    
    // ============ View Functions ============
    
    /// @notice Check if address is a vault
    /// @param vault Address to check
    /// @return isVaultAddress True if address is a vault
    function isVault(address vault) external view returns (bool isVaultAddress);
    
    /// @notice Get wrapper registry address
    /// @return Address of the wrapper registry
    function wrapperRegistry() external view returns (WrapperRegistry);
    
    /// @notice Get insurance manager address
    /// @return Address of the insurance manager
    function insuranceManager() external view returns (InsuranceManager);
}