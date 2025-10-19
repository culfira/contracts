// SPDX-License-Identifier: MIT
// IWrapper.sol
pragma solidity ^0.8.0;

interface IWrapper {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimRewards() external;
    function getBalance(address user) external view returns (uint256);
}