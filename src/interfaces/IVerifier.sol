// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

interface IVerifier {
    event NewPauser(address pauser, uint256 chain);
    event RemovedPauser(address pauser, uint256 chain);
    event Paused(address pauser, uint256 chain);
    event Unpaused(address pauser, uint256 chain);

    error ZeroAddress();
    error OnlyManager();
    error OnlySocket();
    error OnlyPauser();
    error PauserAlreadySet();
    error NotPauser();

    function verifyRoot(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) external view returns (bool, bytes32);
}
