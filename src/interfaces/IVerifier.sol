// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface IVerifier {
    /**
     * @notice emits when a new pauser is added
     * @param pauser address of new pauser
     * @param chain chain id for which pauser is added
     */
    event NewPauser(address pauser, uint256 chain);

    /**
     * @notice emits when a pauser is removed
     * @param pauser address of new pauser
     * @param chain chain id for which pauser is added
     */
    event RemovedPauser(address pauser, uint256 chain);

    /**
     * @notice emits when a chain is paused
     * @param pauser address of new pauser
     * @param chain chain id for which pauser is added
     */
    event Paused(address pauser, uint256 chain);

    /**
     * @notice emits when a chain is unpaused
     * @param pauser address of new pauser
     * @param chain chain id for which pauser is added
     */
    event Unpaused(address pauser, uint256 chain);

    error ZeroAddress();
    error OnlyManager();
    error OnlyPauser();
    error PauserAlreadySet();
    error NotPauser();

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ dest chain id
     * @param packetId_ packet id
     */
    function verifyRoot(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) external view returns (bool, bytes32);
}
