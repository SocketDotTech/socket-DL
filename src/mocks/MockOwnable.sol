// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

import "../utils/Ownable.sol";
import "forge-std/Test.sol";

contract MockOwnable is Ownable, Test {
    constructor(address owner) Ownable(owner) {}

    function OwnerFunction() external onlyOwner {}

    function PublicFunction() external {}
}
