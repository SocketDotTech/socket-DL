// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/ITransmitManager.sol";
import "./interfaces/ISignatureVerifier.sol";

import "./utils/AccessControl.sol";

contract TransmitManager is ITransmitManager, AccessControl {
    uint256 public chainSlug;
    ISignatureVerifier public signatureVerifier;

    /**
     * @notice emits when a new signature verifier contract is set
     * @param signatureVerifier_ address of new verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier_);

    constructor(
        ISignatureVerifier signatureVerifier_,
        address owner_,
        uint256 chainSlug_
    ) AccessControl(owner_) {
        chainSlug = chainSlug_;
        signatureVerifier = signatureVerifier_;
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

    function payFees(uint256 dstSlug) external payable override {}

    function getMinFees(uint256 dstSlug) external view override {}

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
