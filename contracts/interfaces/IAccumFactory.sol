// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./IAccumulator.sol";
import "./IDeaccumulator.sol";

interface IAccumFactory {
    error InvalidAccumType();

    function deploy(
        uint256 accumType,
        uint256 siblingChainSlug
    ) external returns (IAccumulator, IDeaccumulator);
}
