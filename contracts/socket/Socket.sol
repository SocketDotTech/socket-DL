// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SocketDst.sol";
import {SocketSrc} from "./SocketSrc.sol";

/**
 * @title Socket
 * @notice A contract that acts as both a source and destination for cross-chain transactions.
 * @dev This contract inherits from SocketSrc and SocketDst
 */
contract Socket is SocketSrc, SocketDst {
    /*
     * @notice constructor for creating a new Socket contract instance.
     * @param chainSlug_ The unique identifier of the chain this socket belongs to.
     * @param hasher_ The address of the Hasher contract used to hash the messages before transmitting them.
     * @param transmitManager_ The address of the TransmitManager contract responsible for validating transmitters who seal/propose packets.
     * @param executionManager_ The address of the ExecutionManager contract responsible for managing executors
     * @param capacitorFactory_ The address of the CapacitorFactory contract used to create new Capacitor and Decapacitor contracts.
     * @param owner_ The address of the owner who has the initial admin role.
     */
    constructor(
        uint32 chainSlug_,
        address hasher_,
        address transmitManager_,
        address executionManager_,
        address capacitorFactory_,
        address owner_,
        string memory version_
    ) AccessControlExtended(owner_) SocketBase(chainSlug_, version_) {
        hasher__ = IHasher(hasher_);
        transmitManager__ = ITransmitManager(transmitManager_);
        executionManager__ = IExecutionManager(executionManager_);
        capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
    }
}
