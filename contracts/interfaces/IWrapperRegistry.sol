// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IWrapperRegistry
 * @notice Interface for managing wrapper token registry in Culfira protocol
 * @dev Central registry for all wrapper tokens and their configurations
 */
interface IWrapperRegistry {
    // --- Structs ---
    struct WrapperInfo {
        address wrapperToken;
        address underlyingToken;
        string symbol;
        bool isActive;
        uint256 createdAt;
        uint256 totalWrapped;
    }
    
    // --- Events ---
    event WrapperRegistered(
        address indexed wrapperToken,
        address indexed underlyingToken,
        string symbol
    );
    event WrapperStatusUpdated(address indexed wrapperToken, bool isActive);
    event WrapperRemoved(address indexed wrapperToken);
    
    // --- Registry Management ---
    /**
     * @notice Register a new wrapper token
     * @param underlyingToken Address of underlying token
     * @param symbol Symbol for wrapper token (e.g., "xHBAR")
     * @return wrapperToken Address of created wrapper token
     */
    function registerWrapper(
        address underlyingToken,
        string memory symbol
    ) external returns (address wrapperToken);
    
    /**
     * @notice Update wrapper token status
     * @param wrapperToken Wrapper token address
     * @param isActive New status
     */
    function setWrapperStatus(address wrapperToken, bool isActive) external;
    
    /**
     * @notice Remove wrapper token from registry
     * @param wrapperToken Wrapper token address
     */
    function removeWrapper(address wrapperToken) external;
    
    // --- View Functions ---
    /**
     * @notice Get wrapper info by wrapper token address
     * @param wrapperToken Wrapper token address
     * @return info Wrapper information
     */
    function getWrapperInfo(address wrapperToken) external view returns (WrapperInfo memory info);
    
    /**
     * @notice Get wrapper token by underlying token
     * @param underlyingToken Underlying token address
     * @return wrapperToken Wrapper token address (zero if not found)
     */
    function getWrapperByUnderlying(address underlyingToken) external view returns (address wrapperToken);
    
    /**
     * @notice Get all registered wrapper tokens
     * @return wrappers Array of wrapper information
     */
    function getAllWrappers() external view returns (WrapperInfo[] memory wrappers);
    
    /**
     * @notice Get active wrapper tokens only
     * @return wrappers Array of active wrapper information
     */
    function getActiveWrappers() external view returns (WrapperInfo[] memory wrappers);
    
    /**
     * @notice Check if wrapper token is registered and active
     * @param wrapperToken Wrapper token address
     * @return True if registered and active
     */
    function isActiveWrapper(address wrapperToken) external view returns (bool);
    
    /**
     * @notice Get total number of registered wrappers
     * @return Total count
     */
    function wrapperCount() external view returns (uint256);
}