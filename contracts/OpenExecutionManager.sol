// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/ISignatureVerifier.sol";

import "./libraries/RescueFundsLib.sol";
import "./libraries/SignatureVerifierLib.sol";
import "./libraries/FeesHelper.sol";
import "./utils/AccessControlExtended.sol";
import {WITHDRAW_ROLE, RESCUE_ROLE, GOVERNANCE_ROLE, EXECUTOR_ROLE, FEES_UPDATER_ROLE} from "./utils/AccessRoles.sol";
import {FEES_UPDATE_SIG_IDENTIFIER, RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER, MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER, MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER} from "./utils/SigIdentifiers.sol";
import "./ExecutionManager.sol";


/**
 * @title ExecutionManager
 * @dev Implementation of the IExecutionManager interface, providing functions for executing cross-chain transactions and
 * managing execution fees. This contract also implements the AccessControl interface, allowing for role-based
 * access control.
 */
contract OpenExecutionManager is ExecutionManager {

    constructor(
        address owner_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_
    ) ExecutionManager(owner_, chainSlug_, signatureVerifier_)
    {}

    /**
     * @notice Checks whether the provided signer address is an executor for the given packed message and signature
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
