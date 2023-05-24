// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ISignatureVerifier.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/SignatureVerifierLib.sol";
import "./ExecutionManager.sol";

/**
 * @title OpenExecutionManager
 * @dev ExecutionManager contract along with open execution
 */
contract OpenExecutionManager is ExecutionManager {
    constructor(
        address owner_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_
    ) ExecutionManager(owner_, chainSlug_, signatureVerifier_) {}

    /**
     * @notice This function allows all executors
     * @param packedMessage Packed message to be executed
     * @param sig Signature of the message
     * @return executor Address of the executor
     * @return isValidExecutor Boolean value indicating whether the executor is valid or not
     */
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view override returns (address executor, bool isValidExecutor) {
        executor = SignatureVerifierLib.recoverSignerFromDigest(
            packedMessage,
            sig
        );
        isValidExecutor = true;
    }
}
