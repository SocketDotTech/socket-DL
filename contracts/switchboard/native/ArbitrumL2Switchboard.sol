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
    uint256 public confirmGasLimit;
    IArbSys public immutable arbsys__ = IArbSys(address(100));
    event UpdatedConfirmGasLimit(uint256 confirmGasLimit);

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
     * @dev Constructor function that sets initial values for the confirmGasLimit, arbsys__, and the NativeSwitchboardBase parent contract.
     * @param chainSlug_ A uint32 representing the ID of the L2 network.
     * @param confirmGasLimit_ A uint256 representing the amount of gas that will be needed to confirm the execution of a transaction on the L2 network.
     * @param initiateGasLimit_ A uint256 representing the amount of gas that will be needed to initiate a transaction on the L2 network.
     * @param executionOverhead_ A uint256 representing the amount of gas that is needed for a transaction execution overhead on the L2 network.
     * @param owner_ The address that will have the default admin role in the AccessControlExtended parent contract.
     * @param socket_ The address of the Ethereum mainnet Native Meta-Transaction Executor contract.
     * @param gasPriceOracle_ An IGasPriceOracle contract used to calculate gas prices for transactions.
     */
    constructor(
        uint32 chainSlug_,
        uint256 confirmGasLimit_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address owner_,
        address socket_,
        IGasPriceOracle gasPriceOracle_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            socket_,
            chainSlug_,
            initiateGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
    {
        confirmGasLimit = confirmGasLimit_;
    }

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

    /**
    * @dev Calculates the minimum switchboard fees that should be charged to the user for executing
    *    a cross-chain transaction based on the destination relative gas price and source gas price.
    * @param dstRelativeGasPrice_ The relative gas price of the destination chain.
    * @param sourceGasPrice_ The gas price of the source chain.
    * @return minSwitchboardFees The minimum switchboard fees in wei that should be charged 
                                 to the user for executing a cross-chain transaction.
    */
    function _getMinSwitchboardFees(
        uint32,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return
            initiateGasLimit *
            sourceGasPrice_ +
            confirmGasLimit *
            dstRelativeGasPrice_;
    }

    /**
     * @notice Updates the confirm gas limit for a given nonce and signature.
     * @dev This function can only be called by the contract owner.
     * @param nonce_ The nonce for which to update the confirm gas limit.
     * @param confirmGasLimit_ The new confirm gas limit to set.
     * @param signature_ The signature that authorizes the update.
     */
    function updateConfirmGasLimit(
        uint256 nonce_,
        uint256 confirmGasLimit_,
        bytes memory signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "L1_RECEIVE_GAS_LIMIT_UPDATE",
                    chainSlug,
                    nonce_,
                    confirmGasLimit_
                )
            ),
            signature_
        );

        if (!_hasRole(GAS_LIMIT_UPDATER_ROLE, gasLimitUpdater))
            revert NoPermit(GAS_LIMIT_UPDATER_ROLE);
        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        confirmGasLimit = confirmGasLimit_;
        emit UpdatedConfirmGasLimit(confirmGasLimit_);
    }
}
