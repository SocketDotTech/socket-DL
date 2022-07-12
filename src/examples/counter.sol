// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";

contract Counter is IPlug {
    // immutables
    address public immutable socket;

    address public owner;

    // application state
    uint256 public counter;

    // application ops
    bytes32 OP_ADD = keccak256("OP_ADD");
    bytes32 OP_SUB = keccak256("OP_SUB");

    constructor(address _socket) {
        socket = _socket;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "can only be called by owner");
        _;
    }

    function localAddOperation(uint256 amount) public {
        _addOperation(amount);
    }

    function localSubOperation(uint256 amount) public {
        _subOperation(amount);
    }

    function remoteAddOperation(uint256 chainId, uint256 amount) public {
        bytes memory payload = abi.encode(OP_ADD, amount);
        _outbound(chainId, payload);
    }

    function remoteSubOperation(uint256 chainId, uint256 amount) public {
        bytes memory payload = abi.encode(OP_SUB, amount);
        _outbound(chainId, payload);
    }

    function inbound(bytes calldata payload) external override {
        require(msg.sender == socket, "Counter: Invalid Socket");
        (bytes32 operationType, uint256 amount) = abi.decode(
            payload,
            (bytes32, uint256)
        );

        if (operationType == OP_ADD) {
            _addOperation(amount);
        } else if (operationType == OP_SUB) {
            _subOperation(amount);
        } else {
            revert("CounterMock: Invalid Operation");
        }
    }

    function _outbound(uint256 targetChain, bytes memory payload) private {
        ISocket(socket).outbound(targetChain, payload);
    }

    //
    // base ops
    //
    function _addOperation(uint256 amount) private {
        counter += amount;
    }

    function _subOperation(uint256 amount) private {
        counter -= amount;
    }

    // settings
    function setSocketConfig(
        uint256 remoteChainId,
        address remotePlug,
        address signer,
        address accum,
        address deaccum,
        address verifier
    ) external onlyOwner {
        ISocket(socket).setInboundConfig(
            remoteChainId,
            remotePlug,
            signer,
            deaccum,
            verifier
        );
        ISocket(socket).setOutboundConfig(remoteChainId, remotePlug, accum);
    }

    function setupComplete() external {
        owner = address(0);
    }
}
