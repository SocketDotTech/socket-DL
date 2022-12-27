// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISwitchboard.sol";
import "../interfaces/ISocket.sol";
import "../utils/AccessControl.sol";

contract FastSwitchboard is ISwitchboard, AccessControl {
    ISocket public socket;
    uint256 public immutable chainSlug;
    uint256 public timeoutInSeconds;

    // keccak256("WATCHER")
    bytes32 WATCHER_ROLE =
        0xc5f1d4258c62728075c120634c70b3363b74519d0ae4b53891a4b74fe4bfa0b8;

    bool tripFuse;

    // total watchers registered
    uint256 public totalWatchers;

    // attester => root => is attested
    mapping(address => mapping(bytes32 => bool)) public isAttested;

    // root => total attestations
    mapping(bytes32 => uint256) private attestations;

    event SocketSet(address newSocket_);
    event SwitchboardTripped(bool tripFuse_);
    event RootAttested(bytes32 root, address attester);

    error TransferFailed();
    error FeesNotEnough();
    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();

    constructor(
        address owner_,
        address socket_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        chainSlug = chainSlug_;
        socket = ISocket(socket_);

        timeoutInSeconds = timeoutInSeconds_;
    }

    function attest(bytes32 root) external {
        if (!_hasRole(WATCHER_ROLE, msg.sender)) revert WatcherNotFound();
        if (isAttested[msg.sender][root]) revert AlreadyAttested();

        isAttested[msg.sender][root] = true;
        attestations[root]++;

        emit RootAttested(root, msg.sender);
    }

    function payFees(
        uint256 msgGasLimit,
        uint256 remoteChainSlug
    ) external payable override {
        // TODO: updated with issue #45
        uint256 expectedFees = 0;
        if (msg.value != expectedFees) revert FeesNotEnough();
    }

    // todo: switchboard might need src chain slug and packet id while verifying details here?
    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param root root
     * @param proposeTime time at which packet was proposed
     */
    function allowPacket(
        bytes32 root,
        uint256 proposeTime
    ) external view override returns (bool) {
        if (tripFuse) return false;
        if (block.timestamp - proposeTime > timeoutInSeconds) return true;

        // this should be chain dependent? (need src chain slug)
        if (attestations[root] != totalWatchers) return false;
        return true;
    }

    /**
     * @notice updates socket_
     * @param socket_ address of Notary
     */
    function setSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
        emit SocketSet(socket_);
    }

    /**
     * @notice pause/unpause execution
     * @param tripFuse_ bool indicating verification is active or not
     */
    function trip(bool tripFuse_) external onlyOwner {
        tripFuse = tripFuse_;
        emit SwitchboardTripped(tripFuse_);
    }

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));
        (bool success, ) = account_.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice adds a watcher for `remoteChainSlug_` chain
     * @param watcher_ watcher address
     */
    function grantWatcherRole(address watcher_) external onlyOwner {
        if (_hasRole(WATCHER_ROLE, watcher_)) revert WatcherFound();
        _grantRole(WATCHER_ROLE, watcher_);
        totalWatchers++;
    }

    /**
     * @notice removes a watcher from `remoteChainSlug_` chain list
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(address watcher_) external onlyOwner {
        if (!_hasRole(WATCHER_ROLE, watcher_)) revert WatcherNotFound();
        _revokeRole(WATCHER_ROLE, watcher_);
        totalWatchers--;
    }
}
