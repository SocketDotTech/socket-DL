// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/arbitrum/IArbSys.sol";

import "../../libraries/AddressAliasHelper.sol";
import "./NativeSwitchboardBase.sol";

/**

@title ArbitrumL2Switchboard
@dev A contract that facilitates communication between the Ethereum mainnet and 
     the Arbitrum Layer 2 network by handling incoming and outgoing messages through the Arbitrum Sys contract. 
     Inherits from NativeSwitchboardBase contract that handles communication with 
     other Layer 1 networks.
*/
contract ArbitrumL2Switchboard is NativeSwitchboardBase {
    IArbSys public immutable arbsys__ = IArbSys(address(100));

    /**
     * @dev Modifier that checks if the sender of the transaction is the remote native switchboard on the L1 network.
     * If not, reverts with an InvalidSender error message.
     */
    modifier onlyRemoteSwitchboard() override {
        if (
            msg.sender !=
            AddressAliasHelper.applyL1ToL2Alias(remoteNativeSwitchboard)
        ) revert InvalidSender();
        _;
    }

    /**
     * @dev Constructor function that sets initial values for the arbsys__, and the NativeSwitchboardBase parent contract.
     * @param chainSlug_ A uint32 representing the ID of the L2 network.
     * @param initiateGasLimit_ A uint256 representing the amount of gas that will be needed to initiate a transaction on the L2 network.
     * @param owner_ The address that will have the default admin role in the AccessControl parent contract.
     * @param socket_ The address of the Ethereum mainnet Native Meta-Transaction Executor contract.
     */
    constructor(
        uint32 chainSlug_,
        uint256 initiateGasLimit_,
        address owner_,
        address socket_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            socket_,
            chainSlug_,
            initiateGasLimit_,
            signatureVerifier_
        )
    {}

    /**
     * @dev Sends a message to the L1 network requesting a confirmation for the packet with the specified packet ID.
     * @param packetId_ A bytes32 representing the ID of the packet to be confirmed.
     */
    function initiateNativeConfirmation(bytes32 packetId_) external {
        bytes memory data = _encodeRemoteCall(packetId_);

        arbsys__.sendTxToL1(remoteNativeSwitchboard, data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    /**
    @dev Internal function to encode a remote call to L1.
         receivePacket on the Arbitrum L2 chain.
    @param packetId_ The ID of the packet to receive.
    @return data A bytes array containing the encoded function call.
    */
    function _encodeRemoteCall(
        bytes32 packetId_
    ) internal view returns (bytes memory data) {
        data = abi.encodeWithSelector(
            this.receivePacket.selector,
            packetId_,
            _getRoot(packetId_)
        );
    }
}
