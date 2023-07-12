// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./SocketDst.sol";
import {SocketSrc} from "./SocketSrc.sol";

/**
 * @title Socket
 * @notice Core-contract containing all the core-socket utilities.
 * @dev This contract inherits from SocketSrc and SocketDst
 */
contract Socket is SocketSrc, SocketDst {
    /*
     * @notice constructor for creating a new Socket contract instance.
     * @param chainSlug_ The unique identifier of the chain this socket is deployed on.
     * @param hasher_ The address of the Hasher contract used to pack the message before transmitting them.
     * @param capacitorFactory_ The address of the CapacitorFactory contract used to create new Capacitor and DeCapacitor contracts.
     * @param owner_ The address of the owner who has the initial admin role.
     * @param version_ The version string which is hashed and stored in socket.
     */
    constructor(
        uint32 chainSlug_,
        address hasher_,
        address capacitorFactory_,
        address owner_,
        string memory version_
    ) AccessControlExtended(owner_) SocketBase(chainSlug_, version_) {
        hasher__ = IHasher(hasher_);
        capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
    }
}
