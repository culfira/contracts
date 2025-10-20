// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./WrapperToken.sol";

/// @title WrapperRegistry - Registry for all wrapper tokens
contract WrapperRegistry is Ownable {
    
    // ============ State Variables ============
    
    /// @dev List of registered wrapper tokens
    address[] private wrapperList;
    
    /// @dev Mapping from underlying token to wrapper token
    mapping(address => address) public underlyingToWrapper;
    
    /// @dev Mapping from wrapper token to underlying token
    mapping(address => address) public wrapperToUnderlying;
    
    /// @dev Check if wrapper is registered
    mapping(address => bool) public isRegistered;
    
    // ============ Events ============
    
    event WrapperRegistered(
        address indexed underlyingToken,
        address indexed wrapperToken,
        string name,
        string symbol
    );
    event WrapperRemoved(address indexed wrapperToken);
    
    // ============ Errors ============
    
    error WrapperAlreadyExists();
    error WrapperNotFound();
    error InvalidAddress();
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {}
    
    // ============ External Functions ============
    
    /// @notice Register a new wrapper token
    function registerWrapper(
        address underlyingToken_,
        string memory name_,
        string memory symbol_
    ) external onlyOwner returns (address) {
        if (underlyingToken_ == address(0)) revert InvalidAddress();
        if (underlyingToWrapper[underlyingToken_] != address(0)) {
            revert WrapperAlreadyExists();
        }
        
        WrapperToken wrapper = new WrapperToken(
            IERC20(underlyingToken_),
            name_,
            symbol_
        );
        
        address wrapperAddress = address(wrapper);
        
        wrapperList.push(wrapperAddress);
        underlyingToWrapper[underlyingToken_] = wrapperAddress;
        wrapperToUnderlying[wrapperAddress] = underlyingToken_;
        isRegistered[wrapperAddress] = true;
        
        emit WrapperRegistered(underlyingToken_, wrapperAddress, name_, symbol_);
        
        return wrapperAddress;
    }
    
    /// @notice Remove a wrapper token from registry
    function removeWrapper(address wrapperToken) external onlyOwner {
        if (!isRegistered[wrapperToken]) revert WrapperNotFound();
        
        address underlying = wrapperToUnderlying[wrapperToken];
        
        delete underlyingToWrapper[underlying];
        delete wrapperToUnderlying[wrapperToken];
        isRegistered[wrapperToken] = false;
        
        emit WrapperRemoved(wrapperToken);
    }
    
    /// @notice Get wrapper token for underlying token
    function getWrapper(address underlyingToken) external view returns (address) {
        return underlyingToWrapper[underlyingToken];
    }
    
    /// @notice Get all registered wrappers
    function getAllWrappers() external view returns (address[] memory) {
        return wrapperList;
    }
    
    /// @notice Get total number of wrappers
    function wrapperCount() external view returns (uint256) {
        return wrapperList.length;
    }
}