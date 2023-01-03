// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/ITransmitManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./interfaces/IOracle.sol";

import "./utils/AccessControl.sol";

contract TransmitManager is ITransmitManager, AccessControl {
    uint256 public chainSlug;
    ISignatureVerifier public signatureVerifier;
    IOracle public oracle;

    uint256 public sealGasLimit;
    mapping(uint256 => uint256) public proposeGasLimit;

    error TransferFailed();
    error InsufficientTransmitFees();

    event SealGasLimitSet(uint256 gasLimit_);
    event ProposeGasLimitSet(uint256 dstChainSlug_, uint256 gasLimit_);

    /**
     * @notice emits when a new signature verifier contract is set
     * @param signatureVerifier_ address of new verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier_);

    constructor(
        ISignatureVerifier signatureVerifier_,
        IOracle oracle_,
        address owner_,
        uint256 chainSlug_,
        uint256 sealGasLimit_
    ) AccessControl(owner_) {
        chainSlug = chainSlug_;
        sealGasLimit = sealGasLimit_;
        signatureVerifier = signatureVerifier_;
        oracle = IOracle(oracle_);
    }

    function checkTransmitter(
        uint256 siblingChainSlug_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external view override returns (bool) {
        address transmitter = signatureVerifier.recoverSigner(
            chainSlug,
            packetId_,
            root_,
            signature_
        );

        return _hasRole(_transmitterRole(siblingChainSlug_), transmitter);
    }

    // can be used for different checks related to oracle
    function isTransmitter(
        address transmitter_,
        uint256 siblingChainSlug_
    ) external view override returns (bool) {
        return _hasRole(_transmitterRole(siblingChainSlug_), transmitter_);
    }

    function payFees(uint256 siblingChainSlug_) external payable override {
        if (msg.value < _calculateFees(siblingChainSlug_))
            revert InsufficientTransmitFees();
    }

    function getMinFees(
        uint256 siblingChainSlug_
    ) external view override returns (uint256) {
        return _calculateFees(siblingChainSlug_);
    }

    function _calculateFees(
        uint256 siblingChainSlug_
    ) internal view returns (uint256 minTransmissionFees) {
        uint256 siblingRelativeGasPrice = oracle.getRelativeGasPrice(
            siblingChainSlug_
        );

        unchecked {
            minTransmissionFees =
                sealGasLimit *
                tx.gasprice +
                proposeGasLimit[siblingChainSlug_] *
                siblingRelativeGasPrice;
        }
    }

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));
        (bool success, ) = account_.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
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
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    /**
     * @notice adds a transmitter for `remoteChainSlug_` chain
     * @param remoteChainSlug_ remote chain slug
     * @param transmitter_ transmitter address
     */
    function grantTransmitterRole(
        uint256 remoteChainSlug_,
        address transmitter_
    ) external onlyOwner {
        _grantRole(_transmitterRole(remoteChainSlug_), transmitter_);
    }

    /**
     * @notice removes an transmitter from `remoteChainSlug_` chain list
     * @param remoteChainSlug_ remote chain slug
     * @param transmitter_ transmitter address
     */
    function revokeTransmitterRole(
        uint256 remoteChainSlug_,
        address transmitter_
    ) external onlyOwner {
        _revokeRole(_transmitterRole(remoteChainSlug_), transmitter_);
    }

    function _transmitterRole(
        uint256 chainSlug_
    ) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }
}
