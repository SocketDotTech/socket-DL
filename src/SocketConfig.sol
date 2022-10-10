// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";

abstract contract SocketConfig is ISocket, AccessControl(msg.sender) {
    Config[] public configs;
    mapping(bytes32 => uint256) public override destConfigs;
    mapping(address => mapping(uint256 => PlugConfig)) public plugConfigs;

    function addConfig(
        uint256 destChainId_,
        address accum_,
        address deaccum_,
        address verifier_,
        string calldata integrationType_
    ) external onlyOwner returns (uint256 configId) {
        bytes32 destConfigId = keccak256(
            abi.encode(destChainId_, integrationType_)
        );
        if (destConfigs[destConfigId] != 0) revert ConfigExists();

        configId = _setConfig(accum_, deaccum_, verifier_);
        destConfigs[destConfigId] = configId;

        emit ConfigAdded(
            accum_,
            deaccum_,
            verifier_,
            destChainId_,
            configId,
            integrationType_
        );
    }

    function _setConfig(
        address accum_,
        address deaccum_,
        address verifier_
    ) internal returns (uint256 configId) {
        Config memory config;

        config.accum = accum_;
        config.deaccum = deaccum_;
        config.verifier = verifier_;

        configId = configs.length;
        configs.push(config);
    }

    /// @inheritdoc ISocket
    function setPlugConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        string memory integrationType_
    ) external override {
        uint256 configId = destConfigs[
            keccak256(abi.encode(remoteChainId_, integrationType_))
        ];
        if (configId == 0) revert InvalidConfigId();

        PlugConfig storage plugConfig = plugConfigs[msg.sender][remoteChainId_];

        plugConfig.remotePlug = remotePlug_;
        plugConfig.configId = configId;

        emit PlugConfigSet(remotePlug_, remoteChainId_, configId);
    }

    function getConfig(uint256 index)
        external
        view
        returns (
            address,
            address,
            address
        )
    {
        Config memory config = configs[index];
        return (config.accum, config.deaccum, config.verifier);
    }

    function getPlugConfig(uint256 remoteChainId_, address plug_)
        external
        view
        returns (
            address accum,
            address deaccum,
            address verifier,
            uint256 configId
        )
    {
        PlugConfig memory plugConfig = plugConfigs[plug_][remoteChainId_];
        Config memory config = configs[plugConfig.configId];
        return (
            config.accum,
            config.deaccum,
            config.verifier,
            plugConfig.configId
        );
    }
}
