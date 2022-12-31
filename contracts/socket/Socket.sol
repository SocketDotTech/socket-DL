// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SocketBase.sol";
import "./SocketSrc.sol";
import "./SocketDst.sol";

contract Socket is SocketSrc, SocketDst {
    constructor(
        uint32 chainSlug_,
        address hasher_,
        address transmitManager_
    ) SocketBase(chainSlug_, hasher_, transmitManager_) {}
}
