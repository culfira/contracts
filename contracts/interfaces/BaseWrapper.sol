// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBaseWrapper.sol";

abstract contract BaseWrapper is IWrapper, Ownable {
    string private _protocolName;

    constructor(string memory name) Ownable(msg.sender) {
        _protocolName = name;
    }

    function protocolName() external view override returns (string memory) {
        return _protocolName;
    }

    function setProtocolName(string memory name) external override onlyOwner {
        _protocolName = name;
    }
}
