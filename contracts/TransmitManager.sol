// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ITransmitManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./interfaces/IGasPriceOracle.sol";

import "./utils/AccessControlExtended.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/FeesHelper.sol";
import {GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, GAS_LIMIT_UPDATER_ROLE} from "./utils/AccessRoles.sol";

/**
 * @title TransmitManager
 * @notice The TransmitManager contract facilitates communication between chains
 * @dev This contract is responsible for verifying signatures and updating gas limits
 * @dev This contract inherits AccessControlExtended which manages access control
 */
contract TransmitManager is ITransmitManager, AccessControlExtended {
    ISignatureVerifier public signatureVerifier__;
    IGasPriceOracle public gasPriceOracle__;

    uint32 public immutable chainSlug;
    uint256 public sealGasLimit;

    // chain slug => propose gas limit
    mapping(uint256 => uint256) public proposeGasLimit;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    error InsufficientTransmitFees();
    error InvalidNonce();

    /**
     * @notice Emitted when a new gas price oracle contract is set
     * @param gasPriceOracle The address of the new gas price oracle contract
     */
    event GasPriceOracleSet(address gasPriceOracle);
    /**
     * @notice Emitted when the seal gas limit is updated
     * @param gasLimit The new seal gas limit
     */
    event SealGasLimitSet(uint256 gasLimit);
    /**
     * @notice Emitted when the propose gas limit is updated
     * @param dstChainSlug The destination chain slug for which the propose gas limit is updated
     * @param gasLimit The new propose gas limit
     */
    event ProposeGasLimitSet(uint256 dstChainSlug, uint256 gasLimit);
    /**
     * @notice Emitted when a new signature verifier contract is set
     * @param signatureVerifier The address of the new signature verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier);

    /**
     * @notice Initializes the TransmitManager contract
     * @param signatureVerifier_ The address of the signature verifier contract
     * @param gasPriceOracle_ The address of the gas price oracle contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     * @param chainSlug_ The chain slug of the current contract
     * @param sealGasLimit_ The gas limit for seal transactions
     */
    constructor(
        ISignatureVerifier signatureVerifier_,
        IGasPriceOracle gasPriceOracle_,
        address owner_,
        uint32 chainSlug_,
        uint256 sealGasLimit_
    ) AccessControlExtended(owner_) {
        chainSlug = chainSlug_;
        sealGasLimit = sealGasLimit_;
        signatureVerifier__ = signatureVerifier_;
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
    }

    /**
     * @notice verifies if the given signatures recovers a valid transmitter
     * @dev signature sent to this function can be reused on other chains
     * @dev hence caller should add some identifier to prevent this.
     * @dev In socket, this is handled by the calling functions everywhere.
     * @param siblingSlug_ sibling id for which transmitter is registered
     * @param digest_ digest which is signed by transmitter
     * @param signature_ signature
     */
    function checkTransmitter(
        uint32 siblingSlug_,
        bytes32 digest_,
        bytes calldata signature_
    ) external view override returns (address, bool) {
        address transmitter = signatureVerifier__.recoverSignerFromDigest(
            digest_,
            signature_
        );

        return (
            transmitter,
            _hasRole("TRANSMITTER_ROLE", siblingSlug_, transmitter)
        );
    }

    /**
     * @notice takes fees for the given sibling slug from socket for seal and propose
     * @param siblingChainSlug_ sibling id
     */
    function payFees(uint32 siblingChainSlug_) external payable override {}

    /**
     * @notice calculates fees for the given sibling slug
     * @param siblingChainSlug_ sibling id
     */
    function getMinFees(
        uint32 siblingChainSlug_
    ) external view override returns (uint256) {
        return _calculateMinFees(siblingChainSlug_);
    }

    /**
     * @notice calculates fees for the given sibling slug
     * @param siblingChainSlug_ sibling id
     */
    function _calculateMinFees(
        uint32 siblingChainSlug_
    ) internal view returns (uint256 minTransmissionFees) {
        (
            uint256 sourceGasPrice,
            uint256 siblingRelativeGasPrice
        ) = gasPriceOracle__.getGasPrices(siblingChainSlug_);

        minTransmissionFees =
            sealGasLimit *
            sourceGasPrice +
            proposeGasLimit[siblingChainSlug_] *
            siblingRelativeGasPrice;
    }

    /**
     * @notice withdraws fees from contract
     * @param account_ withdraw fees to
     */
    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        FeesHelper.withdrawFees(account_);
    }

    /**
     * @notice updates seal gas limit
     * @param nonce_ nonce of transmitter
     * @param gasLimit_ new seal gas limit
     * @param signature_ signature
     */
    function setSealGasLimit(
        uint256 nonce_,
        uint256 gasLimit_,
        bytes calldata signature_
    ) external {
        address gasLimitUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "SEAL_GAS_LIMIT_UPDATE",
                    chainSlug,
                    nonce_,
                    gasLimit_
                )
            ),
            signature_
        );

        if (!_hasRole(GAS_LIMIT_UPDATER_ROLE, gasLimitUpdater))
            revert NoPermit(GAS_LIMIT_UPDATER_ROLE);

        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        sealGasLimit = gasLimit_;
        emit SealGasLimitSet(gasLimit_);
    }

    /**
     * @notice updates propose gas limit for `dstChainSlug_`
     * @param nonce_ nonce of transmitter
     * @param dstChainSlug_ dest slug
     * @param gasLimit_ new propose gas limit
     * @param signature_ signature
     */
    function setProposeGasLimit(
        uint256 nonce_,
        uint256 dstChainSlug_,
        uint256 gasLimit_,
        bytes calldata signature_
    ) external override {
        address gasLimitUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "PROPOSE_GAS_LIMIT_UPDATE",
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    gasLimit_
                )
            ),
            signature_
        );

        if (!_hasRole("GAS_LIMIT_UPDATER_ROLE", dstChainSlug_, gasLimitUpdater))
            revert NoPermit("GAS_LIMIT_UPDATER_ROLE");

        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        proposeGasLimit[dstChainSlug_] = gasLimit_;
        emit ProposeGasLimitSet(dstChainSlug_, gasLimit_);
    }

    /**
     * @notice updates gasPriceOracle__
     * @param gasPriceOracle_ address of Gas Price Oracle
     */
    function setGasPriceOracle(
        address gasPriceOracle_
    ) external onlyRole(GOVERNANCE_ROLE) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        emit GasPriceOracleSet(gasPriceOracle_);
    }

    /**
     * @notice updates signatureVerifier_
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
