// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IAccumFactory.sol";
import "./accumulators/SingleAccum.sol";
import "./accumulators/HashChainAccum.sol";
import "./deaccumulators/SingleDeaccum.sol";
import "./deaccumulators/HashChainDeaccum.sol";

contract AccumFactory is IAccumFactory {
    function deploy(
        uint256 accumType,
        uint256 /** siblingChainSlug */
    ) external override returns (IAccumulator, IDeaccumulator) {
        if (accumType == 1) {
            return (new SingleAccum(msg.sender), new SingleDeaccum());
        }
        if (accumType == 2) {
            return (new HashChainAccum(msg.sender), new HashChainDeaccum());
        }
        revert InvalidAccumType();
    }
}
