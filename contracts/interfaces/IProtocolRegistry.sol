// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IProtocolRegistry - Interface for protocol authorization registry
interface IProtocolRegistry {
    
    // ============ Enums ============
    
    enum ProtocolCategory {
        DEX,                    // Decentralized Exchanges (SaucerSwap, etc.)
        LENDING,               // Lending protocols (Compound, Aave-style)
        YIELD_FARMING,         // Yield farming protocols
        STAKING,              // Staking protocols
        LIQUIDITY_MINING,     // Liquidity mining protocols
        DERIVATIVES,          // Derivatives protocols
        INSURANCE,            // Insurance protocols
        CROSS_CHAIN,          // Cross-chain bridges
        OTHER                 // Other DeFi protocols
    }
    
    // ============ Structs ============
    
    struct ProtocolInfo {
        string name;                    // Protocol name (e.g., "SaucerSwap")
        string description;             // Protocol description
        ProtocolCategory category;      // Protocol category
        string website;                 // Protocol website URL
        bool isActive;                  // Whether protocol is currently active
        uint256 addedTimestamp;         // When protocol was added
        address deployer;               // Who deployed/requested this protocol
    }
    
    // ============ Events ============
    
    event ProtocolAdded(
        address indexed protocol,
        string name,
        ProtocolCategory indexed category
    );
    
    event ProtocolRemoved(
        address indexed protocol,
        string name
    );
    
    event ProtocolUpdated(
        address indexed protocol,
        string name,
        ProtocolCategory indexed category
    );
    
    // ============ Functions ============
    
    function addProtocol(address protocol, ProtocolInfo calldata info) external;
    function removeProtocol(address protocol) external;
    function updateProtocol(address protocol, ProtocolInfo calldata info) external;
    function batchAddProtocols(address[] calldata protocols, ProtocolInfo[] calldata infos) external;
    
    function getAllAuthorizedProtocols() external view returns (address[] memory);
    function getProtocolsByCategory(ProtocolCategory category) external view returns (address[] memory);
    function getProtocolInfo(address protocol) external view returns (ProtocolInfo memory);
    function getProtocolCount() external view returns (uint256);
    function isAuthorizedProtocol(address protocol) external view returns (bool);
    function areProtocolsAuthorized(address[] calldata protocols) external view returns (bool[] memory);
}