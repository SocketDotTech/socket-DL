// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./ICapacitor.sol";
import "./IDecapacitor.sol";

/**
 * @title ICapacitorFactory
 * @notice Interface for a factory contract that deploys new instances of `ICapacitor` and `IDecapacitor` contracts.
 */
interface ICapacitorFactory {
    /**
     * @dev Emitted when an invalid capacitor type is requested during deployment.
     */
    error InvalidCapacitorType();

    /**
     * @notice Deploys a new instance of an `ICapacitor` and `IDecapacitor` contract with the specified parameters.
     * @param capacitorType The type of the capacitor to be deployed.
     * @param siblingChainSlug The identifier of the sibling chain.
     * @param maxPacketLength The maximum length of a packet.
     * @return Returns the deployed `ICapacitor` and `IDecapacitor` contract instances.
     */
    function deploy(
        uint256 capacitorType,
        uint32 siblingChainSlug,
        uint256 maxPacketLength
    ) external returns (ICapacitor, IDecapacitor);
}
