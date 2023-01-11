// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SocketBase.sol";
import "./SocketSrc.sol";
import "./SocketDst.sol";
import "../libraries/SafeTransferLib.sol";

contract Socket is SocketSrc, SocketDst {
    using SafeTransferLib for IERC20;

    constructor(
        uint32 chainSlug_,
        address hasher_,
        address transmitManager_,
        address capacitorFactory_
    ) SocketBase(chainSlug_, hasher_, transmitManager_, capacitorFactory_) {}

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) external onlyOwner {
        if (token == address(0)) {
            payable(userAddress).transfer(amount);
        } else {
            // do we need safe transfer?
            IERC20(token).transfer(userAddress, amount);
        }
    }
}
