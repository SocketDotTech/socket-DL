// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISocket {
    event MessageTransmitted(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 nonce,
        bytes payload
    );

    error InvalidRemotePlug();

    error InvalidProof();

    error DappVerificationFailed();

    error MessageAlreadyExecuted();

    function outbound(uint256 remoteChainId_, bytes calldata payload_) external;

    function execute(
        uint256 remoteChainId_,
        address localPlug_,
        uint256 nonce,
        address attester_,
        address remoteAccum_,
        uint256 packetId_,
        bytes calldata payload_,
        bytes calldata deaccumProof_
    ) external;

    // TODO: add confs and blocking/non-blocking
    struct InboundConfig {
        address remotePlug;
        address deaccum;
        address verifier;
    }

    struct OutboundConfig {
        address accum;
        address remotePlug;
    }

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_
    ) external;

    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external;
}
