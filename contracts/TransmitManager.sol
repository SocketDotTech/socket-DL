// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "./interfaces/ISocket.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./libraries/RescueFundsLib.sol";
import "./utils/AccessControlExtended.sol";
import {GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, TRANSMITTER_ROLE, FEES_UPDATER_ROLE} from "./utils/AccessRoles.sol";
import {FEES_UPDATE_SIG_IDENTIFIER} from "./utils/SigIdentifiers.sol";

/**
 * @title TransmitManager
 * @notice The TransmitManager contract managers transmitter which facilitates communication between chains
 * @dev This contract is responsible for verifying signatures and updating gas limits
 * @dev This contract inherits AccessControlExtended which manages access control
 * @dev The transmission fees is collected in execution manager which can be pulled from it when needed
 */
contract TransmitManager is ITransmitManager, AccessControlExtended {
    // chain slug of the current chain
    uint32 public immutable chainSlug;
    // socket contract
    ISocket public immutable socket__;
    // signature verifier contract
    ISignatureVerifier public signatureVerifier__;

    // feeUpdater => nextNonce
    mapping(address => uint256) public nextNonce;

    // triggered when nonce is not as expected for feeUpdater recovered from sig
    error InvalidNonce();

    /**
     * @notice Emitted when a new signature verifier contract is set
     * @param signatureVerifier The address of the new signature verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier);
    event ExecutionManagerSet(address executionManager);

    /**
     * @notice Emitted when the transmissionFees is updated
     * @param dstChainSlug The destination chain slug for which the transmissionFees is updated
     * @param transmissionFees The new transmissionFees
     */
    event TransmissionFeesSet(uint256 dstChainSlug, uint256 transmissionFees);

    /**
     * @notice Initializes the TransmitManager contract
     * @param signatureVerifier_ The address of the signature verifier contract
     * @param socket_ The address of socket contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     * @param chainSlug_ The chain slug of the current chain
     */
    constructor(
        ISignatureVerifier signatureVerifier_,
        ISocket socket_,
        address owner_,
        uint32 chainSlug_
    ) AccessControlExtended(owner_) {
        chainSlug = chainSlug_;
        signatureVerifier__ = signatureVerifier_;
        socket__ = socket_;
    }

    /**
     * @notice verifies if the given signatures recovers a valid transmitter
     * @dev signature sent to this function is validated against digest
     * @dev recovered transmitter should add have transmitter role for `siblingSlug_`
     * @dev This function is called by socket which creates the digest which is used to recover sig
     * @param siblingSlug_ sibling id for which transmitter is registered
     * @param digest_ digest which is signed by transmitter
     * @param signature_ signature
     */
    function checkTransmitter(
        uint32 siblingSlug_,
        bytes32 digest_,
        bytes calldata signature_
    ) external view override returns (address, bool) {
        address transmitter = signatureVerifier__.recoverSigner(
            digest_,
            signature_
        );

        return (
            transmitter,
            _hasRoleWithSlug(TRANSMITTER_ROLE, siblingSlug_, transmitter)
        );
    }

    /// @inheritdoc ITransmitManager
    function setTransmissionFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint128 transmissionFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    transmissionFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        // nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }

        socket__.executionManager__().setTransmissionMinFees(
            dstChainSlug_,
            transmissionFees_
        );
        emit TransmissionFeesSet(dstChainSlug_, transmissionFees_);
    }

    /// @inheritdoc ITransmitManager
    function receiveFees(uint32) external payable override {
        require(msg.sender == address(socket__.executionManager__()));
    }

    /**
     * @notice withdraws fees from contract
     * @dev caller needs withdraw role
     * @param account_ withdraw fees to
     */
    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        if (account_ == address(0)) revert ZeroAddress();
        SafeTransferLib.safeTransferETH(account_, address(this).balance);
    }

    /**
     * @notice updates signatureVerifier_
     * @dev caller needs governance role
     * @param signatureVerifier_ address of Signature Verifier
     */
    function setSignatureVerifier(
        address signatureVerifier_
    ) external onlyRole(GOVERNANCE_ROLE) {
        signatureVerifier__ = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    /**
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
