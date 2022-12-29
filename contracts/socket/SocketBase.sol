// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IHasher.sol";
import "../utils/ReentrancyGuard.sol";
import "./SocketConfig.sol";

// todo: remove
interface ITransmitManager {
    function checkTransmitter(
        uint256 chainSlug,
        uint256 siblingChainSlug,
        bytes32 root,
        bytes calldata signature
    ) external view returns (bool);
}

abstract contract SocketBase is SocketConfig, ReentrancyGuard {
    IHasher public _hasher__;
    ITransmitManager public _transmitManager__;
    uint256 public _chainSlug;

    error InvalidAttester();

    constructor(
        uint32 chainSlug_,
        address hasher_,
        address transmitManager_,
        address capacitorFactory_
    ) SocketConfig(capacitorFactory_) {
        _chainSlug = chainSlug_;
        _hasher__ = IHasher(hasher_);
        _transmitManager__ = ITransmitManager(transmitManager_);
    }

    function setHasher(address hasher_) external onlyOwner {
        _hasher__ = IHasher(hasher_);
    }

    // TODO: in discussion
    /**
     * @notice updates transmitManager_
     * @param transmitManager_ address of Transmit Manager
     */
    function setTransmitManager(address transmitManager_) external onlyOwner {
        _transmitManager__ = ITransmitManager(transmitManager_);
        emit TransmitManagerSet(transmitManager_);
    }
}
