// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IPlug {
    /**
     * @notice executes the message received from source chain
     * @dev this should be only executable by socket
     * @param payload_ the data which is needed by plug at inbound call on destination
     */
    function inbound(bytes calldata payload_) external;
}
