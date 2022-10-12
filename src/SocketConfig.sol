// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";

abstract contract SocketConfig is ISocket, AccessControl(msg.sender) {
    // integrationType => remoteChainId => address
    mapping(bytes32 => mapping(uint256 => address)) public verifiers;
    mapping(bytes32 => mapping(uint256 => address)) public accums;
    mapping(bytes32 => mapping(uint256 => address)) public deaccums;
    mapping(bytes32 => mapping(uint256 => bool)) public configExists;

    // plug => remoteChainId => config(verifiers, accums, deaccums, destPlug)
    mapping(address => mapping(uint256 => PlugConfig)) public plugConfigs;

    function addConfig(
        uint256 remoteChainId_,
        address accum_,
        address deaccum_,
        address verifier_,
        string calldata integrationType_
    ) external returns (bytes32 integrationType) {
        integrationType = keccak256(abi.encode(integrationType_));
        if (configExists[integrationType][remoteChainId_])
            revert ConfigExists();

        verifiers[integrationType][remoteChainId_] = verifier_;
        accums[integrationType][remoteChainId_] = accum_;
        deaccums[integrationType][remoteChainId_] = deaccum_;
        configExists[integrationType][remoteChainId_] = true;

        emit ConfigAdded(
            accum_,
            deaccum_,
            verifier_,
            remoteChainId_,
            integrationType
        );
    }

    /// @inheritdoc ISocket
    function setPlugConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        string memory integrationType_
    ) external override {
        bytes32 integrationType = keccak256(abi.encode(integrationType_));
        if (!configExists[integrationType][remoteChainId_])
            revert InvalidIntegrationType();

        PlugConfig storage plugConfig = plugConfigs[msg.sender][remoteChainId_];

        plugConfig.remotePlug = remotePlug_;
        plugConfig.accum = accums[integrationType][remoteChainId_];
        plugConfig.deaccum = deaccums[integrationType][remoteChainId_];
        plugConfig.verifier = verifiers[integrationType][remoteChainId_];
        plugConfig.integrationType = integrationType;

        emit PlugConfigSet(remotePlug_, remoteChainId_, integrationType);
    }

    function getConfigs(uint256 remoteChainId_, string memory integrationType_)
        external
        view
        returns (
            address,
            address,
            address
        )
    {
        bytes32 integrationType = keccak256(abi.encode(integrationType_));
        return (
            accums[integrationType][remoteChainId_],
            deaccums[integrationType][remoteChainId_],
            verifiers[integrationType][remoteChainId_]
        );
    }

    function getPlugConfig(uint256 remoteChainId_, address plug_)
        external
        view
        returns (
            address accum,
            address deaccum,
            address verifier,
            address remotePlug
        )
    {
        PlugConfig memory plugConfig = plugConfigs[plug_][remoteChainId_];
        return (
            plugConfig.accum,
            plugConfig.deaccum,
            plugConfig.verifier,
            plugConfig.remotePlug
        );
    }
}
