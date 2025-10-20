// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IVaultFactory
 * @notice Interface for creating and managing multi-asset vault instances
 * @dev Factory pattern for deploying standardized multi-asset vaults
 */
interface IVaultFactory {
    // --- Structs ---
    struct VaultConfig {
        string name;                     // Vault name
        uint256 duration;               // Vault duration in seconds
        uint256 targetAmount;           // Target total value to reach
        uint256 maxMembers;             // Maximum number of members
        uint256 minHealthFactor;        // Minimum health factor (1e18 = 100%)
        uint256 contributionFrequency;  // How often contributions are due (seconds)
        address[] allowedAssets;        // Allowed wrapper tokens
        uint256[] assetWeights;         // Asset weights for pool (sum to 1e18)
        bool requiresInsurance;         // Whether insurance is mandatory
        uint256 insurancePenalty;       // Penalty rate for violations (1e18 = 100%)
    }
    
    struct VaultInfo {
        address vaultAddress;
        string name;
        address creator;
        uint256 createdAt;
        uint256 totalMembers;
        uint256 currentValue;
        uint256 targetAmount;
        bool isActive;
        VaultStatus status;
    }
    
    enum VaultStatus {
        PENDING,        // Created but not started
        ACTIVE,         // Currently running
        COMPLETED,      // Successfully completed
        FAILED,         // Failed to reach target
        EMERGENCY       // Emergency state
    }
    
    // --- Events ---
    event VaultCreated(
        address indexed vaultAddress,
        address indexed creator,
        string name,
        uint256 targetAmount,
        uint256 duration
    );
    event VaultTemplateUpdated(string templateName, address implementation);
    event FactoryConfigUpdated(address indexed admin, string parameter, uint256 value);
    event VaultStatusUpdated(address indexed vault, VaultStatus status);
    
    // --- Core Functions ---
    /**
     * @notice Create a new multi-asset vault
     * @param config Vault configuration parameters
     * @return vaultAddress Address of newly created vault
     */
    function createVault(VaultConfig memory config) external returns (address vaultAddress);
    
    /**
     * @notice Create vault from predefined template
     * @param templateName Template identifier
     * @param customParams Custom parameters to override template defaults
     * @return vaultAddress Address of newly created vault
     */
    function createVaultFromTemplate(
        string memory templateName,
        bytes memory customParams
    ) external returns (address vaultAddress);
    
    /**
     * @notice Clone existing vault with similar configuration
     * @param sourceVault Address of vault to clone
     * @param customConfig Custom configuration overrides
     * @return vaultAddress Address of newly created vault
     */
    function cloneVault(
        address sourceVault,
        VaultConfig memory customConfig
    ) external returns (address vaultAddress);
    
    // --- Template Management ---
    /**
     * @notice Add or update vault template
     * @param templateName Template identifier
     * @param implementation Template implementation address
     * @param defaultConfig Default configuration for template
     */
    function setVaultTemplate(
        string memory templateName,
        address implementation,
        VaultConfig memory defaultConfig
    ) external;
    
    /**
     * @notice Remove vault template
     * @param templateName Template to remove
     */
    function removeVaultTemplate(string memory templateName) external;
    
    /**
     * @notice Get available vault templates
     * @return templates Array of template names
     */
    function getVaultTemplates() external view returns (string[] memory templates);
    
    /**
     * @notice Get template configuration
     * @param templateName Template identifier
     * @return config Template default configuration
     */
    function getTemplateConfig(string memory templateName) external view returns (VaultConfig memory config);
    
    // --- Vault Registry ---
    /**
     * @notice Register vault creation (called by created vaults)
     * @param creator Vault creator address
     * @param config Vault configuration
     */
    function registerVault(address creator, VaultConfig memory config) external;
    
    /**
     * @notice Update vault status
     * @param vault Vault address
     * @param status New status
     */
    function updateVaultStatus(address vault, VaultStatus status) external;
    
    /**
     * @notice Remove vault from registry (emergency only)
     * @param vault Vault address to remove
     */
    function removeVault(address vault) external;
    
    // --- Factory Configuration ---
    /**
     * @notice Set factory parameters
     * @param param Parameter name
     * @param value Parameter value
     */
    function setFactoryParameter(string memory param, uint256 value) external;
    
    /**
     * @notice Set required wrapper registry
     * @param registry WrapperRegistry address
     */
    function setWrapperRegistry(address registry) external;
    
    /**
     * @notice Set required insurance manager
     * @param manager InsuranceManager address
     */
    function setInsuranceManager(address manager) external;
    
    // --- View Functions ---
    /**
     * @notice Get vaults created by user
     * @param creator Creator address
     * @return vaults Array of vault addresses
     */
    function getVaultsByCreator(address creator) external view returns (address[] memory vaults);
    
    /**
     * @notice Get vaults where user is member
     * @param member Member address
     * @return vaults Array of vault addresses
     */
    function getVaultsByMember(address member) external view returns (address[] memory vaults);
    
    /**
     * @notice Get all active vaults
     * @return vaults Array of active vault addresses
     */
    function getActiveVaults() external view returns (address[] memory vaults);
    
    /**
     * @notice Get vault information
     * @param vault Vault address
     * @return info Vault information struct
     */
    function getVaultInfo(address vault) external view returns (VaultInfo memory info);
    
    /**
     * @notice Get total number of vaults created
     * @return count Total vault count
     */
    function getTotalVaultCount() external view returns (uint256 count);
    
    /**
     * @notice Check if address is a valid vault created by this factory
     * @param vault Address to check
     * @return True if vault was created by this factory
     */
    function isValidVault(address vault) external view returns (bool);
    
    /**
     * @notice Get factory configuration
     * @return wrapperRegistry Address of wrapper registry
     * @return insuranceManager Address of insurance manager
     * @return creationFee Fee for creating vaults
     * @return maxVaultDuration Maximum allowed vault duration
     */
    function getFactoryConfig() external view returns (
        address wrapperRegistry,
        address insuranceManager,
        uint256 creationFee,
        uint256 maxVaultDuration
    );
    
    /**
     * @notice Calculate estimated vault creation cost
     * @param config Vault configuration
     * @return totalCost Total cost including fees and deposits
     */
    function calculateCreationCost(VaultConfig memory config) external view returns (uint256 totalCost);
    
    /**
     * @notice Get vaults by status
     * @param status Vault status to filter by
     * @return vaults Array of vault addresses with specified status
     */
    function getVaultsByStatus(VaultStatus status) external view returns (address[] memory vaults);
}