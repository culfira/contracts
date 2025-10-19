// SPDX-License-Identifier: MIT
// IWrapper.sol
pragma solidity ^0.8.0;

interface IWrapper {
    function protocolName() external view returns (string memory);
    function setProtocolName(string memory name) external;
}