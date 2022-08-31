// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/INotary.sol";
import "../utils/AccessControl.sol";
import "../interfaces/IAccumulator.sol";
import "../interfaces/ISignatureVerifier.sol";

contract BondedNotary is INotary, AccessControl(msg.sender) {
    uint256 private _minBondAmount;
    uint256 private _bondClaimDelay;
    uint256 private immutable _chainId;
    ISignatureVerifier private _signatureVerifier;

    // attester => bond amount
    mapping(address => uint256) private _bonds;

    struct UnbondData {
        uint256 amount;
        uint256 claimTime;
    }
    // attester => unbond data
    mapping(address => UnbondData) private _unbonds;

    // attester => accumAddress => packetId => sig hash
    mapping(address => mapping(address => mapping(uint256 => bytes32)))
        private _localSignatures;

    // remoteChainId => accumAddress => packetId => root
    mapping(uint256 => mapping(address => mapping(uint256 => bytes32)))
        private _remoteRoots;

    constructor(
        uint256 minBondAmount_,
        uint256 bondClaimDelay_,
        uint256 chainId_,
        address signatureVerifier_
    ) {
        _setMinBondAmount(minBondAmount_);
        _setBondClaimDelay(bondClaimDelay_);
        _setSignatureVerifier(signatureVerifier_);
        _chainId = chainId_;
    }

    function addBond() external payable override {
        _bonds[msg.sender] += msg.value;
        emit BondAdded(msg.sender, msg.value, _bonds[msg.sender]);
    }

    function reduceBond(uint256 amount) external override {
        uint256 newBond = _bonds[msg.sender] - amount;

        if (newBond < _minBondAmount) revert InvalidBondReduce();

        _bonds[msg.sender] = newBond;
        emit BondReduced(msg.sender, amount, newBond);

        payable(msg.sender).transfer(amount);
    }

    function unbondAttester() external override {
        if (_unbonds[msg.sender].claimTime != 0) revert UnbondInProgress();

        uint256 amount = _bonds[msg.sender];
        uint256 claimTime = block.timestamp + _bondClaimDelay;

        _bonds[msg.sender] = 0;
        _unbonds[msg.sender] = UnbondData(amount, claimTime);

        emit Unbonded(msg.sender, amount, claimTime);
    }

    function claimBond() external override {
        if (_unbonds[msg.sender].claimTime > block.timestamp)
            revert ClaimTimeLeft();

        uint256 amount = _unbonds[msg.sender].amount;
        _unbonds[msg.sender] = UnbondData(0, 0);
        emit BondClaimed(msg.sender, amount);

        payable(msg.sender).transfer(amount);
    }

    function minBondAmount() external view returns (uint256) {
        return _minBondAmount;
    }

    function bondClaimDelay() external view returns (uint256) {
        return _bondClaimDelay;
    }

    function signatureVerifier() external view returns (address) {
        return address(_signatureVerifier);
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function getBond(address attester) external view returns (uint256) {
        return _bonds[attester];
    }

    function getUnbondData(address attester)
        external
        view
        returns (uint256, uint256)
    {
        return (_unbonds[attester].amount, _unbonds[attester].claimTime);
    }

    function setMinBondAmount(uint256 amount) external onlyOwner {
        _setMinBondAmount(amount);
    }

    function setBondClaimDelay(uint256 delay) external onlyOwner {
        _setBondClaimDelay(delay);
    }

    function setSignatureVerifier(address signatureVerifier_)
        external
        onlyOwner
    {
        _setSignatureVerifier(signatureVerifier_);
    }

    function submitSignature(address accumAddress_, bytes calldata signature_)
        external
        override
    {
        (bytes32 root, uint256 packetId) = IAccumulator(accumAddress_)
            .sealPacket();

        bytes32 digest = keccak256(
            abi.encode(_chainId, accumAddress_, packetId, root)
        );
        address attester = _signatureVerifier.recoverSigner(digest, signature_);

        if (_bonds[attester] < _minBondAmount) revert InvalidBond();
        _localSignatures[attester][accumAddress_][packetId] = keccak256(
            signature_
        );

        emit SignatureSubmitted(accumAddress_, packetId, signature_);
    }

    function challengeSignature(
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_,
        bytes calldata signature_
    ) external override {
        bytes32 digest = keccak256(
            abi.encode(_chainId, accumAddress_, packetId_, root_)
        );
        address attester = _signatureVerifier.recoverSigner(digest, signature_);
        bytes32 oldSig = _localSignatures[attester][accumAddress_][packetId_];

        if (oldSig != keccak256(signature_)) {
            uint256 bond = _unbonds[attester].amount + _bonds[attester];
            payable(msg.sender).transfer(bond);
            emit ChallengedSuccessfully(
                attester,
                accumAddress_,
                packetId_,
                msg.sender,
                bond
            );
        }
    }

    function _setMinBondAmount(uint256 amount) private {
        _minBondAmount = amount;
        emit MinBondAmountSet(amount);
    }

    function _setBondClaimDelay(uint256 delay) private {
        _bondClaimDelay = delay;
        emit BondClaimDelaySet(delay);
    }

    function _setSignatureVerifier(address signatureVerifier_) private {
        _signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function submitRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external override {
        bytes32 digest = keccak256(
            abi.encode(remoteChainId_, accumAddress_, packetId_, root_)
        );
        address attester = _signatureVerifier.recoverSigner(digest, signature_);

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();

        if (_remoteRoots[remoteChainId_][accumAddress_][packetId_] != 0)
            revert RemoteRootAlreadySubmitted();

        _remoteRoots[remoteChainId_][accumAddress_][packetId_] = root_;
        emit RemoteRootSubmitted(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );
    }

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view override returns (bytes32) {
        return _remoteRoots[remoteChainId_][accumAddress_][packetId_];
    }

    function grantAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        _grantRole(_attesterRole(remoteChainId_), attester_);
    }

    function revokeAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        _revokeRole(_attesterRole(remoteChainId_), attester_);
    }

    function _attesterRole(uint256 chainId_) internal pure returns (bytes32) {
        return bytes32(chainId_);
    }
}
