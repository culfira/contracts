// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBaseWrapper.sol";

abstract contract BaseWrapper is IWrapper, Ownable {
    address public underlyingToken;

    constructor(address _underlyingToken) {
        underlyingToken = _underlyingToken;
        _transferOwnership(msg.sender); // From Ownable
    }
}