// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;
import "./ExecutionManager.sol";

/**
 * @title OpenExecutionManager
 * @dev ExecutionManager contract with open execution
 */
contract OpenExecutionManager is ExecutionManager {
    /**
     * @dev Constructor for OpenExecutionManager contract
     * @param owner_ Address of the contract owner
     * @param chainSlug_ chain slug used to identify current chain
     * @param signatureVerifier_ Address of the signature verifier contract
     * @param socket_ Address of the socket contract
     */
    constructor(
        address owner_,
        uint32 chainSlug_,
        ISocket socket_,
        ISignatureVerifier signatureVerifier_
    ) ExecutionManager(owner_, chainSlug_, socket_, signatureVerifier_) {}

    /**
     * @notice This function allows all executors.
     * @notice As executor recovered here is used for fee accounting, it is critical to provide a valid
     * signature else it can deprive the executor of their payout
     * @param packedMessage Packed message to be executed
     * @param sig Signature of the message
     * @return executor Address of the executor
     * @return isValidExecutor Boolean value indicating whether the executor is valid or not
     */
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view override returns (address executor, bool isValidExecutor) {
        executor = signatureVerifier__.recoverSigner(packedMessage, sig);
        isValidExecutor = true;
    }
}
