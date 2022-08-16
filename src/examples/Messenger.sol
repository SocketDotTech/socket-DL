// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";

contract Messenger is IPlug {
    // immutables
    address public immutable socket;

    address public owner;
    bytes32 public message;

    constructor(address _socket) {
        socket = _socket;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "can only be called by owner");
        _;
    }

    function sendLocalMessage(bytes32 message_) public {
        _updateMessage(message_);
    }

    function sendRemoteMessage(uint256 chainId_, bytes32 message_) public {
        bytes memory payload = abi.encode(message_);
        _outbound(chainId_, payload);
    }

    function _updateMessage(bytes32 message_) internal {
        message = message_;
    }

    function inbound(bytes calldata payload) external override {
        require(msg.sender == socket, "Counter: Invalid Socket");
        bytes32 message_ = abi.decode(payload, (bytes32));

        _updateMessage(message_);
    }

    function _outbound(uint256 targetChain, bytes memory payload) private {
        ISocket(socket).outbound(targetChain, payload);
    }

    // settings
    function setSocketConfig(
        uint256 remoteChainId,
        address remotePlug,
        address accum,
        address deaccum,
        address verifier,
        bool isSequential
    ) external onlyOwner {
        ISocket(socket).setInboundConfig(
            remoteChainId,
            remotePlug,
            deaccum,
            verifier,
            isSequential
        );
        ISocket(socket).setOutboundConfig(remoteChainId, remotePlug, accum);
    }
}
