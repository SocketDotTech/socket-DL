// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";
import "./interfaces/IAccumulator.sol";
import "./interfaces/IDeaccumulator.sol";
import "./interfaces/IVerifier.sol";
import "./interfaces/IPlug.sol";

contract Socket is ISocket, AccessControl(msg.sender) {
    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    uint256 private _minBondAmount;
    uint256 private _bondClaimDelay;
    uint256 private immutable _chainId;

    // signer => bond amount
    mapping(address => uint256) private _bonds;

    struct UnbondData {
        uint256 amount;
        uint256 claimTime;
    }
    // signer => unbond data
    mapping(address => UnbondData) private _unbonds;

    // signer => accumAddress => batchId => sig hash
    mapping(address => mapping(address => mapping(uint256 => bytes32)))
        private _localSignatures;

    // remoteChainId => accumAddress => batchId => root
    mapping(uint256 => mapping(address => mapping(uint256 => bytes32)))
        private _remoteRoots;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // localPlug => remoteChainId => nonce
    mapping(address => mapping(uint256 => uint256)) private _nonces;

    // packethash => executeStatus
    mapping(bytes32 => bool) private _executedPackets;

    // localPlug => remoteChainId => nextNonce
    mapping(address => mapping(uint256 => uint256)) private _nextNonces;

    constructor(
        uint256 minBondAmount_,
        uint256 bondClaimDelay_,
        uint256 chainId_
    ) {
        _setMinBondAmount(minBondAmount_);
        _setBondClaimDelay(bondClaimDelay_);
        _chainId = chainId_;
    }

    function outbound(uint256 remoteChainId_, bytes calldata payload_)
        external
        override
    {
        OutboundConfig memory config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        uint256 nonce = _nonces[msg.sender][remoteChainId_]++;
        bytes32 packet = _makePacket(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            nonce,
            payload_
        );

        IAccumulator(config.accum).addPacket(packet);
        emit PacketTransmitted(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            nonce,
            payload_
        );
    }

    function inbound(
        uint256 remoteChainId_,
        address localPlug_,
        uint256 nonce_,
        address signer_,
        address remoteAccum_,
        uint256 batchId_,
        bytes calldata payload_,
        bytes calldata deaccumProof_
    ) external override {
        InboundConfig memory config = inboundConfigs[localPlug_][
            remoteChainId_
        ];

        bytes32 packet = _makePacket(
            remoteChainId_,
            config.remotePlug,
            _chainId,
            localPlug_,
            nonce_,
            payload_
        );

        if (_executedPackets[packet]) revert PacketAlreadyExecuted();
        _executedPackets[packet] = true;

        if (
            config.isSequential &&
            nonce_ != _nextNonces[localPlug_][remoteChainId_]++
        ) revert InvalidNonce();

        bytes32 root = _remoteRoots[remoteChainId_][remoteAccum_][batchId_];
        if (
            !IDeaccumulator(config.deaccum).verifyPacketHash(
                root,
                packet,
                deaccumProof_
            )
        ) revert InvalidProof();

        if (
            !IVerifier(config.verifier).verifyRoot(
                signer_,
                remoteChainId_,
                remoteAccum_,
                batchId_,
                root
            )
        ) revert DappVerificationFailed();

        IPlug(localPlug_).inbound(payload_);
    }

    function _makePacket(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 nonce,
        bytes calldata payload
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainId,
                    srcPlug,
                    dstChainId,
                    dstPlug,
                    nonce,
                    payload
                )
            );
    }

    function dropPackets(uint256 remoteChainId_, uint256 count_) external {
        _nextNonces[msg.sender][remoteChainId_] += count_;
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

    function unbondSigner() external override {
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

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function getBond(address signer) external view returns (uint256) {
        return _bonds[signer];
    }

    function getUnbondData(address signer)
        external
        view
        returns (uint256, uint256)
    {
        return (_unbonds[signer].amount, _unbonds[signer].claimTime);
    }

    function setMinBondAmount(uint256 amount) external onlyOwner {
        _setMinBondAmount(amount);
    }

    function setBondClaimDelay(uint256 delay) external onlyOwner {
        _setBondClaimDelay(delay);
    }

    function submitSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_
    ) external override {
        (bytes32 root, uint256 batchId) = IAccumulator(accumAddress_)
            .sealBatch();

        bytes32 digest = keccak256(
            abi.encode(_chainId, accumAddress_, batchId, root)
        );
        address signer = ecrecover(digest, sigV_, sigR_, sigS_);

        if (_bonds[signer] < _minBondAmount) revert InvalidBond();
        _localSignatures[signer][accumAddress_][batchId] = keccak256(
            abi.encode(sigV_, sigR_, sigS_)
        );

        emit SignatureSubmitted(accumAddress_, batchId, sigV_, sigR_, sigS_);
    }

    function challengeSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_,
        bytes32 root_,
        uint256 batchId_
    ) external override {
        bytes32 digest = keccak256(
            abi.encode(_chainId, accumAddress_, batchId_, root_)
        );
        address signer = ecrecover(digest, sigV_, sigR_, sigS_);
        bytes32 oldSig = _localSignatures[signer][accumAddress_][batchId_];

        if (oldSig != keccak256(abi.encode(sigV_, sigR_, sigS_))) {
            uint256 bond = _unbonds[signer].amount + _bonds[signer];
            payable(msg.sender).transfer(bond);
            emit SignatureChallenged(
                signer,
                accumAddress_,
                batchId_,
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

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_,
        bool isSequential_
    ) external override {
        InboundConfig storage config = inboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.remotePlug = remotePlug_;
        config.deaccum = deaccum_;
        config.verifier = verifier_;
        config.isSequential = isSequential_;

        // TODO: emit event
    }

    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external override {
        OutboundConfig storage config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.accum = accum_;
        config.remotePlug = remotePlug_;

        // TODO: emit event
    }

    function submitRemoteRoot(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 batchId_,
        bytes32 root_
    ) external override {
        bytes32 digest = keccak256(
            abi.encode(remoteChainId_, accumAddress_, batchId_, root_)
        );
        address signer = ecrecover(digest, sigV_, sigR_, sigS_);

        if (!_hasRole(_signerRole(remoteChainId_), signer))
            revert InvalidSigner();

        if (_remoteRoots[remoteChainId_][accumAddress_][batchId_] != 0)
            revert RemoteRootAlreadySubmitted();

        _remoteRoots[remoteChainId_][accumAddress_][batchId_] = root_;
        emit RemoteRootSubmitted(
            remoteChainId_,
            accumAddress_,
            batchId_,
            root_
        );
    }

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 batchId_
    ) external view override returns (bytes32) {
        return _remoteRoots[remoteChainId_][accumAddress_][batchId_];
    }

    function grantSignerRole(uint256 remoteChainId_, address signer_)
        external
        override
        onlyOwner
    {
        _grantRole(_signerRole(remoteChainId_), signer_);
    }

    function revokeSignerRole(uint256 remoteChainId_, address signer_)
        external
        override
        onlyOwner
    {
        _revokeRole(_signerRole(remoteChainId_), signer_);
    }

    function _signerRole(uint256 chainId_) internal pure returns (bytes32) {
        return bytes32(chainId_);
    }
}
