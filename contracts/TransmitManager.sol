// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/ITransmitManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./interfaces/IGasPriceOracle.sol";

import "./utils/AccessControlExtended.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/FeesHelper.sol";
import {GOVERNANCE_ROLE, TRANSMITTER_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, GAS_LIMIT_UPDATER_ROLE} from "./utils/AccessRoles.sol";

contract TransmitManager is ITransmitManager, AccessControlExtended {
    ISignatureVerifier public signatureVerifier__;
    IGasPriceOracle public gasPriceOracle__;

    uint32 public immutable chainSlug;
    uint256 public sealGasLimit;
    mapping(uint256 => uint256) public proposeGasLimit;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    error TransferFailed();
    error InsufficientTransmitFees();
    error NonceAlreadyUsed();

    event GasPriceOracleSet(address gasPriceOracle);
    event SealGasLimitSet(uint256 gasLimit);
    event ProposeGasLimitSet(uint256 dstChainSlug, uint256 gasLimit);

    /**
     * @notice emits when a new signature verifier contract is set
     * @param signatureVerifier address of new verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier);

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

    // @param slugs_ packs the siblingChainSlug & sigChainSlug
    // @dev signature sent to this function can be reused on other chains
    // @dev hence caller should add some identifier to stop this.
    // slugs_(256) = siblingChainSlug(128) | sigChainSlug(128)
    // @dev sibling chain slug is required to check the transmitter role
    // @dev sig chain slug is required by signature. On src, this is sibling slug while on
    // destination, it is current chain slug
    function checkTransmitter(
        uint32 siblingSlug,
        bytes32 digest_,
        bytes calldata signature_
    ) external view override returns (address, bool) {
        address transmitter = signatureVerifier__.recoverSignerFromDigest(
            digest_,
            signature_
        );

        return (
            transmitter,
            _hasRole(TRANSMITTER_ROLE, siblingSlug, transmitter)
        );
    }

    function payFees(uint32 siblingChainSlug_) external payable override {}

    function getMinFees(
        uint32 siblingChainSlug_
    ) external view override returns (uint256) {
        return _calculateMinFees(siblingChainSlug_);
    }

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

    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        FeesHelper.withdrawFees(account_);
    }

    /**
     * @notice updates seal gas limit
     * @param gasLimit_ new seal gas limit
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
        if (nonce_ != nonce) revert NonceAlreadyUsed();

        sealGasLimit = gasLimit_;
        emit SealGasLimitSet(gasLimit_);
    }

    /**
     * @notice updates propose gas limit for `dstChainSlug_`
     * @param gasLimit_ new propose gas limit
     */
    function setProposeGasLimit(
        uint256 nonce_,
        uint256 dstChainSlug_,
        uint256 gasLimit_,
        bytes calldata signature_
    ) external {
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

        if (!_hasRole(GAS_LIMIT_UPDATER_ROLE, dstChainSlug_, gasLimitUpdater))
            revert NoPermit(GAS_LIMIT_UPDATER_ROLE);

        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert NonceAlreadyUsed();

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

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
