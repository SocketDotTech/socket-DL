// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISocket.sol";
import "../utils/AccessControl.sol";

abstract contract SocketConfig is ISocket, AccessControl(msg.sender) {
    struct PlugConfig {
        address remotePlug;
        address accum;
        address deaccum;
        address verifier;
        bytes32 inboundIntegrationType;
        bytes32 outboundIntegrationType;
    }

    // integrationType => remoteChainSlug => address
    mapping(bytes32 => mapping(uint256 => address)) public verifiers;
    mapping(bytes32 => mapping(uint256 => address)) public accums;
    mapping(bytes32 => mapping(uint256 => address)) public deaccums;
    mapping(bytes32 => mapping(uint256 => bool)) public configExists;

    // plug => remoteChainSlug => config(verifiers, accums, deaccums, remotePlug)
    mapping(address => mapping(uint256 => PlugConfig)) public plugConfigs;

    event ConfigAdded(
        address accum_,
        address deaccum_,
        address verifier_,
        uint256 remoteChainSlug_,
        bytes32 integrationType_
    );

    error ConfigExists();
    error InvalidIntegrationType();

    function addConfig(
        uint256 remoteChainSlug_,
        address accum_,
        address deaccum_,
        address verifier_,
        string calldata integrationType_
    ) external returns (bytes32 integrationType) {
        integrationType = keccak256(abi.encode(integrationType_));
        if (configExists[integrationType][remoteChainSlug_])
            revert ConfigExists();

        verifiers[integrationType][remoteChainSlug_] = verifier_;
        accums[integrationType][remoteChainSlug_] = accum_;
        deaccums[integrationType][remoteChainSlug_] = deaccum_;
        configExists[integrationType][remoteChainSlug_] = true;

        emit ConfigAdded(
            accum_,
            deaccum_,
            verifier_,
            remoteChainSlug_,
            integrationType
        );
    }

    /// @inheritdoc ISocket
    function setPlugConfig(
        uint256 remoteChainSlug_,
        address remotePlug_,
        string memory inboundIntegrationType_,
        string memory outboundIntegrationType_
    ) external override {
        bytes32 inboundIntegrationType = keccak256(
            abi.encode(inboundIntegrationType_)
        );
        bytes32 outboundIntegrationType = keccak256(
            abi.encode(outboundIntegrationType_)
        );
        if (
            !configExists[inboundIntegrationType][remoteChainSlug_] ||
            !configExists[outboundIntegrationType][remoteChainSlug_]
        ) revert InvalidIntegrationType();

        PlugConfig storage plugConfig = plugConfigs[msg.sender][
            remoteChainSlug_
        ];

        plugConfig.remotePlug = remotePlug_;
        plugConfig.accum = accums[outboundIntegrationType][remoteChainSlug_];
        plugConfig.deaccum = deaccums[inboundIntegrationType][remoteChainSlug_];
        plugConfig.verifier = verifiers[inboundIntegrationType][
            remoteChainSlug_
        ];
        plugConfig.inboundIntegrationType = inboundIntegrationType;
        plugConfig.outboundIntegrationType = outboundIntegrationType;

        emit PlugConfigSet(
            remotePlug_,
            remoteChainSlug_,
            inboundIntegrationType,
            outboundIntegrationType
        );
    }

    function getConfigs(
        uint256 remoteChainSlug_,
        string memory integrationType_
    ) external view returns (address, address, address) {
        bytes32 integrationType = keccak256(abi.encode(integrationType_));
        return (
            accums[integrationType][remoteChainSlug_],
            deaccums[integrationType][remoteChainSlug_],
            verifiers[integrationType][remoteChainSlug_]
        );
    }

    function getPlugConfig(
        uint256 remoteChainSlug_,
        address plug_
    )
        external
        view
        returns (
            address accum,
            address deaccum,
            address verifier,
            address remotePlug,
            bytes32 outboundIntegrationType,
            bytes32 inboundIntegrationType
        )
    {
        PlugConfig memory plugConfig = plugConfigs[plug_][remoteChainSlug_];
        return (
            plugConfig.accum,
            plugConfig.deaccum,
            plugConfig.verifier,
            plugConfig.remotePlug,
            plugConfig.outboundIntegrationType,
            plugConfig.inboundIntegrationType
        );
    }
}
