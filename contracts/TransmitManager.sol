// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/ITransmitManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./interfaces/IGasPriceOracle.sol";

import "./utils/AccessControlWithUint.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/FeesHelper.sol";

contract TransmitManager is ITransmitManager, AccessControlWithUint {
    ISignatureVerifier public signatureVerifier__;
    IGasPriceOracle public gasPriceOracle__;

    uint256 public immutable chainSlug;
    uint256 public sealGasLimit;
    mapping(uint256 => uint256) public proposeGasLimit;

    error TransferFailed();
    error InsufficientTransmitFees();

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
        uint256 chainSlug_,
        uint256 sealGasLimit_
    ) AccessControl(owner_) {
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
        uint256 siblingSlug,
        bytes32 digest_,
        bytes calldata signature_
    ) external view override returns (address, bool) {
        address transmitter = signatureVerifier__.recoverSignerFromDigest(
            digest_,
            signature_
        );

        return (transmitter, _hasRoleWithUint(siblingSlug, transmitter));
    }

    function payFees(uint256 siblingChainSlug_) external payable override {}

    function getMinFees(
        uint256 siblingChainSlug_
    ) external view override returns (uint256) {
        return _calculateMinFees(siblingChainSlug_);
    }

    function _calculateMinFees(
        uint256 siblingChainSlug_
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

    function withdrawFees(address account_) external onlyOwner {
        FeesHelper.withdrawFees(account_);
    }

    /**
     * @notice updates seal gas limit
     * @param gasLimit_ new seal gas limit
     */
    function setSealGasLimit(uint256 gasLimit_) external onlyOwner {
        sealGasLimit = gasLimit_;
        emit SealGasLimitSet(gasLimit_);
    }

    /**
     * @notice updates propose gas limit for `dstChainSlug_`
     * @param gasLimit_ new propose gas limit
     */
    function setProposeGasLimit(
        uint256 dstChainSlug_,
        uint256 gasLimit_
    ) external onlyOwner {
        proposeGasLimit[dstChainSlug_] = gasLimit_;
        emit ProposeGasLimitSet(dstChainSlug_, gasLimit_);
    }

    /**
     * @notice updates gasPriceOracle__
     * @param gasPriceOracle_ address of Gas Price Oracle
     */
    function setGasPriceOracle(address gasPriceOracle_) external onlyOwner {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        emit GasPriceOracleSet(gasPriceOracle_);
    }

    /**
     * @notice updates signatureVerifier_
     * @param signatureVerifier_ address of Signature Verifier
     */
    function setSignatureVerifier(
        address signatureVerifier_
    ) external onlyOwner {
        signatureVerifier__ = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
