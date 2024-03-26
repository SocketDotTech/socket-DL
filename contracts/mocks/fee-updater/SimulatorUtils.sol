pragma solidity 0.8.19;

import "../../interfaces/IDecapacitor.sol";
import "../../interfaces/ISocket.sol";
import "../../interfaces/ISignatureVerifier.sol";
import {TRANSMITTER_ROLE, EXECUTOR_ROLE} from "../../utils/AccessRoles.sol";
import "../../utils/AccessControlExtended.sol";

contract SimulatorUtils is AccessControlExtended {
    ISocket public socket__;
    ISignatureVerifier public signatureVerifier__;

    error InsufficientMsgValue();

    constructor(
        address socket_,
        address signatureVerifier_,
        address signer_,
        uint32 siblingSlug_
    ) AccessControlExtended(msg.sender) {
        socket__ = ISocket(socket_);
        signatureVerifier__ = ISignatureVerifier(signatureVerifier_);
        _grantRoleWithSlug(TRANSMITTER_ROLE, siblingSlug_, signer_);
        _grantRole(EXECUTOR_ROLE, signer_);
    }

    // TM
    function checkTransmitter(
        uint32 siblingSlug_,
        bytes32 digest_,
        bytes calldata signature_
    ) external view returns (address, bool) {
        address transmitter = signatureVerifier__.recoverSigner(
            digest_,
            signature_
        );
        _hasRoleWithSlug(TRANSMITTER_ROLE, siblingSlug_, transmitter);

        return (transmitter, true);
    }

    // EM
    function updateExecutionFees(address, uint128, bytes32) external view {
        if (msg.sender != address(socket__)) return;
    }

    function verifyParams(
        bytes32 executionParams_,
        uint256 msgValue_
    ) external pure {
        uint256 params = uint256(executionParams_);
        uint8 paramType = uint8(params >> 248);

        if (paramType == 0) return;
        uint256 expectedMsgValue = uint256(uint248(params));
        if (msgValue_ < expectedMsgValue) revert InsufficientMsgValue();
    }

    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view returns (address executor, bool isValidExecutor) {
        executor = signatureVerifier__.recoverSigner(packedMessage, sig);
        _hasRole(EXECUTOR_ROLE, executor);
        isValidExecutor = true;
    }
}
