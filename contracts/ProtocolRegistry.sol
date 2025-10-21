// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IProtocolRegistry.sol";

/// @title ProtocolRegistry - Central registry for authorized DeFi protocols
/// @notice Manages list of protocols that can be auto-authorized by WrapperTokens
contract ProtocolRegistry is Ownable, IProtocolRegistry {
    
    // ============ State Variables ============
    
    /// @dev List of authorized protocol addresses
    address[] public authorizedProtocols;
    
    /// @dev Mapping for O(1) lookup of authorized protocols
    mapping(address => bool) public isAuthorizedProtocol;
    
    /// @dev Protocol metadata for each authorized protocol
    mapping(address => ProtocolInfo) public protocolInfo;
    
    /// @dev Protocol categories for organization
    mapping(ProtocolCategory => address[]) public protocolsByCategory;
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {}
    
    // ============ Admin Functions ============
    
    /// @notice Add a new protocol to the authorized list
    /// @param protocol Protocol contract address
    /// @param info Protocol metadata
    function addProtocol(
        address protocol,
        ProtocolInfo calldata info
    ) external onlyOwner {
        require(protocol != address(0), "Invalid protocol address");
        require(!isAuthorizedProtocol[protocol], "Protocol already authorized");
        require(bytes(info.name).length > 0, "Protocol name required");
        
        // Add to main list
        authorizedProtocols.push(protocol);
        isAuthorizedProtocol[protocol] = true;
        protocolInfo[protocol] = info;
        
        // Add to category list
        protocolsByCategory[info.category].push(protocol);
        
        emit ProtocolAdded(protocol, info.name, info.category);
    }
    
    /// @notice Remove protocol from authorized list
    /// @param protocol Protocol contract address
    function removeProtocol(address protocol) external onlyOwner {
        require(isAuthorizedProtocol[protocol], "Protocol not authorized");
        
        ProtocolInfo memory info = protocolInfo[protocol];
        
        // Remove from main list
        _removeFromArray(authorizedProtocols, protocol);
        isAuthorizedProtocol[protocol] = false;
        delete protocolInfo[protocol];
        
        // Remove from category list
        _removeFromArray(protocolsByCategory[info.category], protocol);
        
        emit ProtocolRemoved(protocol, info.name);
    }
    
    /// @notice Update protocol information
    /// @param protocol Protocol contract address
    /// @param info New protocol metadata
    function updateProtocol(
        address protocol,
        ProtocolInfo calldata info
    ) external onlyOwner {
        require(isAuthorizedProtocol[protocol], "Protocol not authorized");
        
        ProtocolInfo memory oldInfo = protocolInfo[protocol];
        
        // If category changed, update category lists
        if (oldInfo.category != info.category) {
            _removeFromArray(protocolsByCategory[oldInfo.category], protocol);
            protocolsByCategory[info.category].push(protocol);
        }
        
        protocolInfo[protocol] = info;
        
        emit ProtocolUpdated(protocol, info.name, info.category);
    }
    
    /// @notice Batch add protocols (for initial setup)
    /// @param protocols Array of protocol addresses
    /// @param infos Array of protocol metadata
    function batchAddProtocols(
        address[] calldata protocols,
        ProtocolInfo[] calldata infos
    ) external onlyOwner {
        require(protocols.length == infos.length, "Array length mismatch");
        
        for (uint256 i = 0; i < protocols.length; i++) {
            if (!isAuthorizedProtocol[protocols[i]]) {
                _addProtocolInternal(protocols[i], infos[i]);
            }
        }
    }
    
    // ============ View Functions ============
    
    /// @notice Get all authorized protocols
    /// @return Array of authorized protocol addresses
    function getAllAuthorizedProtocols() external view returns (address[] memory) {
        return authorizedProtocols;
    }
    
    /// @notice Get protocols by category
    /// @param category Protocol category to filter by
    /// @return Array of protocol addresses in the category
    function getProtocolsByCategory(ProtocolCategory category) external view returns (address[] memory) {
        return protocolsByCategory[category];
    }
    
    /// @notice Get protocol information
    /// @param protocol Protocol contract address
    /// @return Protocol metadata
    function getProtocolInfo(address protocol) external view returns (ProtocolInfo memory) {
        require(isAuthorizedProtocol[protocol], "Protocol not authorized");
        return protocolInfo[protocol];
    }
    
    /// @notice Get number of authorized protocols
    /// @return Total count of authorized protocols
    function getProtocolCount() external view returns (uint256) {
        return authorizedProtocols.length;
    }
    
    /// @notice Check if multiple protocols are authorized
    /// @param protocols Array of protocol addresses to check
    /// @return Array of boolean values indicating authorization status
    function areProtocolsAuthorized(address[] calldata protocols) external view returns (bool[] memory) {
        bool[] memory results = new bool[](protocols.length);
        for (uint256 i = 0; i < protocols.length; i++) {
            results[i] = isAuthorizedProtocol[protocols[i]];
        }
        return results;
    }
    
    // ============ Internal Functions ============
    
    /// @dev Internal function to add protocol without duplicate checks
    function _addProtocolInternal(address protocol, ProtocolInfo calldata info) internal {
        authorizedProtocols.push(protocol);
        isAuthorizedProtocol[protocol] = true;
        protocolInfo[protocol] = info;
        protocolsByCategory[info.category].push(protocol);
        
        emit ProtocolAdded(protocol, info.name, info.category);
    }
    
    /// @dev Remove address from array
    function _removeFromArray(address[] storage array, address target) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }
}