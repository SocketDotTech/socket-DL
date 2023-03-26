// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IHasher.sol";
import "../interfaces/ITransmitManager.sol";
import "../interfaces/IExecutionManager.sol";

import "./SocketConfig.sol";
import {GOVERNANCE_ROLE} from "../utils/AccessRoles.sol";

abstract contract SocketBase is SocketConfig {
    IHasher public hasher__;
    ITransmitManager public transmitManager__;
    IExecutionManager public executionManager__;

    uint32 public chainSlug;
    // incrementing nonce, should be handled in next socket version.
    uint224 public messageCount;

    error InvalidAttester();

    event HasherSet(address hasher);
    event ExecutionManagerSet(address executionManager);

    function setHasher(address hasher_) external onlyRole(GOVERNANCE_ROLE) {
        hasher__ = IHasher(hasher_);
        emit HasherSet(hasher_);
    }

    /**
     * @notice updates transmitManager_
     * @param transmitManager_ address of Transmit Manager
     */
    function setTransmitManager(
        address transmitManager_
    ) external onlyRole(GOVERNANCE_ROLE) {
        transmitManager__ = ITransmitManager(transmitManager_);
        emit TransmitManagerSet(transmitManager_);
    }

    /**
     * @notice updates executionManager_
     * @param executionManager_ address of Execution Manager
     */
    function setExecutionManager(address executionManager_) external onlyOwner {
        executionManager__ = IExecutionManager(executionManager_);
        emit ExecutionManagerSet(executionManager_);
    }
}
