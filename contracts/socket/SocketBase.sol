// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IHasher.sol";
import "../interfaces/ITransmitManager.sol";
import "../interfaces/IExecutionManager.sol";

import "../utils/AccessControlExtended.sol";
import {GOVERNANCE_ROLE} from "../utils/AccessRoles.sol";

import "./SocketConfig.sol";

/**
 * @title SocketBase
 * @notice A contract that is responsible for common storage for src and dest contracts, governance
 * setters and inherits SocketConfig
 */
abstract contract SocketBase is SocketConfig, AccessControlExtended {
    // Hasher contract
    IHasher public hasher__;
    // Transmit Manager contract
    ITransmitManager public transmitManager__;
    // Execution Manager contract
    IExecutionManager public executionManager__;

    // chain slug
    uint32 public immutable chainSlug;
    // incrementing nonce, should be handled in next socket version.
    uint64 public messageCount;
    // current version
    bytes32 public immutable version;

    /**
     * @dev constructs a new Socket contract instance.
     * @param chainSlug_ the chain slug of the contract.
     * @param version_ the string to identify current version.
     */
    constructor(uint32 chainSlug_, string memory version_) {
        chainSlug = chainSlug_;
        version = keccak256(bytes(version_));
    }

    /**
     * @dev An error that is thrown when an invalid signer tries to seal or propose.
     */
    error InvalidTransmitter();

    /**
     * @notice An event that is emitted when the capacitor factory is updated.
     * @param capacitorFactory The address of the new capacitorFactory.
     */
    event CapacitorFactorySet(address capacitorFactory);
    /**
     * @notice An event that is emitted when the hasher is updated.
     * @param hasher The address of the new hasher.
     */
    event HasherSet(address hasher);
    /**
     * @notice An event that is emitted when the executionManager is updated.
     * @param executionManager The address of the new executionManager.
     */
    event ExecutionManagerSet(address executionManager);
    /**
     * @notice An event that is emitted when a new transmitManager contract is set
     * @param transmitManager address of new transmitManager contract
     */
    event TransmitManagerSet(address transmitManager);

    /**
     * @dev Set the capacitor factory contract
     * @dev Only governance can call this function
     * @param capacitorFactory_ The address of the capacitor factory contract
     */
    function setCapacitorFactory(
        address capacitorFactory_
    ) external onlyRole(GOVERNANCE_ROLE) {
        capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
        emit CapacitorFactorySet(capacitorFactory_);
    }

    /**
     * @notice updates hasher_
     * @dev Only governance can call this function
     * @param hasher_ address of hasher
     */
    function setHasher(address hasher_) external onlyRole(GOVERNANCE_ROLE) {
        hasher__ = IHasher(hasher_);
        emit HasherSet(hasher_);
    }

    /**
     * @notice updates executionManager_
     * @dev Only governance can call this function
     * @param executionManager_ address of Execution Manager
     */
    function setExecutionManager(
        address executionManager_
    ) external onlyRole(GOVERNANCE_ROLE) {
        executionManager__ = IExecutionManager(executionManager_);
        emit ExecutionManagerSet(executionManager_);
    }

    /**
     * @notice updates transmitManager_
     * @dev Only governance can call this function
     * @param transmitManager_ address of Transmit Manager
     */
    function setTransmitManager(
        address transmitManager_
    ) external onlyRole(GOVERNANCE_ROLE) {
        transmitManager__ = ITransmitManager(transmitManager_);
        emit TransmitManagerSet(transmitManager_);
    }
}
