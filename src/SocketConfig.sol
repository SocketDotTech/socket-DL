// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";

abstract contract SocketConfig is ISocket, AccessControl(msg.sender) {
    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    mapping(uint256 => mapping(bytes32 => Config)) public configs;

    function addConfig(
        uint256 destChainId_,
        address accum_,
        address deaccum_,
        address verifier_,
        string calldata accumName_
    ) external onlyOwner {
        if (configs[destChainId_][keccak256(abi.encode(accumName_))].isSet)
            revert ConfigExists();

        _setConfig(destChainId_, accum_, deaccum_, verifier_, accumName_);
        emit ConfigAdded(accum_, deaccum_, verifier_, destChainId_, accumName_);
    }

    function _setConfig(
        uint256 destChainId_,
        address accum_,
        address deaccum_,
        address verifier_,
        string calldata accumName_
    ) internal {
        Config storage config = configs[destChainId_][
            keccak256(abi.encode(accumName_))
        ];
        config.accum = accum_;
        config.deaccum = deaccum_;
        config.verifier = verifier_;
        config.isSet = true;
    }

    /// @inheritdoc ISocket
    function setInboundConfig(
        uint256 remoteChainId_,
        bytes32 configId_,
        address remotePlug_
    ) external override {
        InboundConfig storage inboundConfig = inboundConfigs[msg.sender][
            remoteChainId_
        ];

        Config memory config = configs[remoteChainId_][configId_];

        inboundConfig.remotePlug = remotePlug_;
        inboundConfig.deaccum = config.deaccum;
        inboundConfig.verifier = config.verifier;

        emit InboundConfigSet(remotePlug_, config.deaccum, config.verifier);
    }

    /// @inheritdoc ISocket
    function setOutboundConfig(
        uint256 remoteChainId_,
        bytes32 configId_,
        address remotePlug_
    ) external override {
        OutboundConfig storage outboundConfig = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        Config memory config = configs[remoteChainId_][configId_];

        outboundConfig.accum = config.accum;
        outboundConfig.remotePlug = remotePlug_;
        outboundConfig.configId = configId_;

        emit OutboundConfigSet(remotePlug_, config.accum, configId_);
    }
}
