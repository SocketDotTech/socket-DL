// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISocket {
    // to handle stack too deep
    struct ExecuteParams {
        uint256 remoteChainId;
        address localPlug;
        uint256 msgId;
        address remoteAccum;
        uint256 packetId;
        bytes payload;
        bytes deaccumProof;
    }

    event MessageTransmitted(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 msgId,
        bytes payload
    );

    event Executed(bool success, string result);
    event ExecutedBytes(bool success, bytes result);

    error NotAttested();

    error InvalidRemotePlug();

    error InvalidProof();

    error VerificationFailed();

    error MessageAlreadyExecuted();

    function outbound(uint256 remoteChainId_, bytes calldata payload_) external;

    function execute(ExecuteParams calldata executeParams_) external;

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
