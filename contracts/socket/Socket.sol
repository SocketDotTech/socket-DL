// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import {SocketSrc} from "./SocketSrc.sol";
import "./SocketDst.sol";
import "../libraries/RescueFundsLib.sol";

contract Socket is SocketSrc, SocketDst {
    constructor(
        uint32 chainSlug_,
        address hasher_,
        address transmitManager_,
        address executionManager_,
        address capacitorFactory_
    ) {
        _chainSlug = chainSlug_;
        _hasher__ = IHasher(hasher_);
        _transmitManager__ = ITransmitManager(transmitManager_);
        _executionManager__ = IExecutionManager(executionManager_);
        _capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
    }

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token, userAddress, amount);
    }
}
