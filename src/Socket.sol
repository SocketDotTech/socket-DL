// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";
import "./interfaces/IAccumulator.sol";

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

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    // signer => accumAddress => batchId => Signature
    mapping(address => mapping(address => mapping(uint256 => Signature)))
        private _signatures;

    constructor(
        uint256 minBondAmount_,
        uint256 bondClaimDelay_,
        uint256 chainId_
    ) {
        _setMinBondAmount(minBondAmount_);
        _setBondClaimDelay(bondClaimDelay_);
        _chainId = chainId_;
    }

    function outbound(uint256 remoteChainId, bytes calldata payload) external {
        // TODO: add stuff
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
        _signatures[signer][accumAddress_][batchId] = Signature(
            sigV_,
            sigR_,
            sigS_
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
        Signature memory sig = _signatures[signer][accumAddress_][batchId_];

        if (sig.v != sigV_ || sig.r != sigR_ || sig.s != sigS_) {
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
        uint256 _remoteChainId,
        address _accumulator,
        address _verifier,
        address _remotePlug
    ) external {
        InboundConfig storage config = inboundConfigs[msg.sender][
            _remoteChainId
        ];
        config.accumulator = _accumulator;
        config.verifier = _verifier;
        config.remotePlug = _remotePlug;

        // TODO: emit event
    }

    function setOutboundConfig(
        uint256 _remoteChainId,
        address _accumulator,
        address _verifier,
        address _remotePlug
    ) external {
        OutboundConfig storage config = outboundConfigs[msg.sender][
            _remoteChainId
        ];
        config.accumulator = _accumulator;
        config.verifier = _verifier;
        config.remotePlug = _remotePlug;

        // TODO: emit event
    }
}
