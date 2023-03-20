// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/ITransmitManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./interfaces/IGasPriceOracle.sol";

import "./utils/AccessControlWithUint.sol";
import "./libraries/RescueFundsLib.sol";

contract TransmitManager is ITransmitManager, AccessControlWithUint {
    ISignatureVerifier public signatureVerifier__;
    IGasPriceOracle public gasPriceOracle__;

    uint256 public chainSlug;
    uint256 public sealGasLimit;
    mapping(uint256 => uint256) public proposeGasLimit;

    error TransferFailed();
    error InsufficientTransmitFees();

    event SealGasLimitSet(uint256 gasLimit);
    event ProposeGasLimitSet(uint256 dstChainSlug, uint256 gasLimit);
    event FeesWithdrawn(address account, uint256 value);

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
    // slugs_(256) = siblingChainSlug(128) | sigChainSlug(128)
    // @dev sibling chain slug is required to check the transmitter role
    // @dev sig chain slug is required by signature. On src, this is sibling slug while on
    // destination, it is current chain slug
    function checkTransmitter(
        uint256 slugs_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external view override returns (address, bool) {
        address transmitter = signatureVerifier__.recoverSigner(
            type(uint128).max & slugs_,
            packetId_,
            root_,
            signature_
        );

        return (transmitter, _hasRoleWithUint(slugs_ >> 128, transmitter));
    }

    function payFees(uint256 siblingChainSlug_) external payable override {
        if (msg.value < _calculateMinFees(siblingChainSlug_))
            revert InsufficientTransmitFees();
    }

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

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));

        uint256 value = address(this).balance;
        (bool success, ) = account_.call{value: value}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(account_, value);
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
