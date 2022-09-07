// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "../interfaces/IVerifier.sol";
import "../interfaces/INotary.sol";

// defines a timeout
// allows a "PAUSER" role to stop processing of messages
// allows an "MANAGER" role to setup "PAUSER"
contract Verifier is IVerifier {
    // immutables
    address public immutable socket;
    address public immutable manager;

    INotary public notary;
    uint256 public immutable _timeoutInSeconds;

    // current state of the verifier
    mapping(uint256 => bool) public isChainActive;

    // pauserState
    mapping(address => mapping(uint256 => bool))
        private isPauserForIncomingChain;

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager();
        _;
    }

    modifier onlySocket() {
        if (msg.sender != socket) revert OnlySocket();
        _;
    }

    modifier onlyPauser(uint256 chain) {
        if (!isPauserForIncomingChain[msg.sender][chain]) revert OnlyPauser();
        _;
    }

    constructor(
        address _socket,
        address _manager,
        address _notary,
        uint256 timeoutInSeconds_
    ) {
        if (
            _socket == address(0) ||
            _manager == address(0) ||
            _notary == address(0)
        ) revert ZeroAddress();

        socket = _socket;
        manager = _manager;
        notary = INotary(_notary);
        // TODO: restrict the timeout durations to a few select options
        _timeoutInSeconds = timeoutInSeconds_;
    }

    function pause(uint256 chain) external onlyPauser(chain) {
        isChainActive[chain] = false;
        emit Paused(msg.sender, chain);
    }

    function activate(uint256 chain) external onlyPauser(chain) {
        isChainActive[chain] = true;
        emit Unpaused(msg.sender, chain);
    }

    function addPauser(address _newPauser, uint256 _incomingChain)
        external
        onlyManager
    {
        if (isPauserForIncomingChain[_newPauser][_incomingChain])
            revert PauserAlreadySet();
        isPauserForIncomingChain[_newPauser][_incomingChain] = true;
        emit NewPauser(_newPauser, _incomingChain);
    }

    function removePauser(address _currentPauser, uint256 _incomingChain)
        external
        onlyManager
    {
        if (!isPauserForIncomingChain[_currentPauser][_incomingChain])
            revert NotPauser();
        isPauserForIncomingChain[_currentPauser][_incomingChain] = false;
        emit RemovedPauser(_currentPauser, _incomingChain);
    }

    function isPauser(address _pauser, uint256 _incomingChainId)
        external
        view
        returns (bool)
    {
        return isPauserForIncomingChain[_pauser][_incomingChainId];
    }

    function verifyRoot(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) external view returns (bool, bytes32) {
        if (isChainActive[remoteChainId_]) {
            (bool isConfirmed, uint256 packetArrivedAt, bytes32 root) = notary
                .getPacketDetails(accumAddress_, remoteChainId_, packetId_);

            if (!isConfirmed) return (false, root);

            // if timed out
            if (block.timestamp - packetArrivedAt > _timeoutInSeconds)
                return (false, root);

            return (true, root);
        }
        return (false, bytes32(0));
    }
}
