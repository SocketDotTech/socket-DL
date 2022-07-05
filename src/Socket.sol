// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";

contract Socket is ISocket, AccessControl(msg.sender) {
    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    uint256 public minBondAmount;
    uint256 public bondClaimDelay;
    uint256 public immutable chainId;

    // signer => bond amount
    mapping(address => uint256) private _bonds;

    struct UnbondData {
        uint256 amount;
        uint256 claimTime;
    }
    // signer => unbond data
    mapping(address => UnbondData) private _unbonds;

    constructor(
        uint256 minBondAmount_,
        uint256 bondClaimDelay_,
        uint256 chainId_
    ) {
        _setMinBondAmount(minBondAmount_);
        _setBondClaimDelay(bondClaimDelay_);
        chainId = chainId_;
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

        if (newBond < minBondAmount) revert InvalidBondReduce();

        _bonds[msg.sender] = newBond;
        emit BondReduced(msg.sender, amount, newBond);

        payable(msg.sender).transfer(amount);
    }

    function unbondSigner() external override {
        if (_unbonds[msg.sender].claimTime != 0) revert UnbondInProgress();

        uint256 amount = _bonds[msg.sender];
        uint256 claimTime = block.timestamp + bondClaimDelay;

        _bonds[msg.sender] = 0;
        _unbonds[msg.sender] = UnbondData(amount, claimTime);

        emit Unbonded(msg.sender, amount, claimTime);
    }

    function claimBond() external override {
        if (_unbonds[msg.sender].claimTime < block.timestamp)
            revert ClaimTimeLeft();

        uint256 amount = _unbonds[msg.sender].amount;
        _unbonds[msg.sender] = UnbondData(0, 0);
        emit BondClaimed(msg.sender, amount);

        payable(msg.sender).transfer(amount);
    }

    function setMinBondAmount(uint256 amount) external onlyOwner {
        _setMinBondAmount(amount);
    }

    function setBondClaimDelay(uint256 delay) external onlyOwner {
        _setBondClaimDelay(delay);
    }

    function _setMinBondAmount(uint256 amount) private {
        minBondAmount = amount;
        emit MinBondAmountSet(amount);
    }

    function _setBondClaimDelay(uint256 delay) private {
        bondClaimDelay = delay;
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
