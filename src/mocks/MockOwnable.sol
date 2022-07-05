// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../utils/Ownable.sol";

contract MockOwnable is Ownable {
    constructor(address owner) Ownable(owner) {}

    function ownerFunction() external onlyOwner {}

    function publicFunction() external {}
}
