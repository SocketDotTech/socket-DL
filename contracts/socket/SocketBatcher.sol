// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControl.sol";
import "../interfaces/ISocket.sol";
import "../interfaces/ICapacitor.sol";
import "../switchboard/default-switchboards/FastSwitchboard.sol";
import "../interfaces/INativeRelay.sol";
import {RESCUE_ROLE, SOCKET_RELAYER_ROLE } from "../utils/AccessRoles.sol";

/**
 * @title SocketBatcher
 * @notice A contract that facilitates the batching of packets across chains. It manages requests for sealing, proposing, attesting, and executing packets across multiple chains.
 * It also has functions for setting gas limits, execution overhead, and registering switchboards.
 * @dev This contract uses the AccessControl contract for managing role-based access control.
 */
contract SocketBatcher is AccessControl {

    // Allowlist to control who can receive funds through the withdrawals function
    mapping(address => bool) public allowlist;

    address constant MOCK_ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*
     * @notice Constructs the SocketBatcher contract and grants the RESCUE_ROLE to the contract deployer.
     * @param owner_ The address of the contract deployer, who will be granted the RESCUE_ROLE.
     */
    constructor(address owner_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice A struct representing a request to seal a batch of packets on the source chain.
     * @param batchSize The number of packets to be sealed in the batch.
     * @param capacitorAddress The address of the capacitor contract on the source chain.
     * @param signature The signature of the packet data.
     */
    struct SealRequest {
        uint256 batchSize;
        address capacitorAddress;
        bytes signature;
    }

    /**
     * @notice A struct representing a proposal request for a packet.
     * @param packetId The ID of the packet being proposed.
     * @param root The Merkle root of the packet data.
     * @param switchboard The address of switchboard
     * @param signature The signature of the packet data.
     */
    struct ProposeRequest {
        bytes32 packetId;
        bytes32 root;
        address switchboard;
        bytes signature;
    }

    /**
     * @notice A struct representing a proposal trip request.
     * @param switchboard The address of switchboard
     * @param nonce The nonce of watcher for this request.
     * @param packetId The ID of the packet being proposed.
     * @param proposalCount The proposal Count for the proposal.
     * @param signature The signature of the packet data.
     */
    struct ProposalTripRequest {
        address switchboard;
        uint256 nonce;
        bytes32 packetId;
        uint256 proposalCount;
        bytes signature;
    }

    /**
     * @notice A struct representing an attestation request for a packet.
     * @param packetId The ID of the packet being attested.
     * @param srcChainSlug The slug of the source chain.
     * @param signature The signature of the packet data.
     */
    struct AttestRequest {
        address switchboard;
        bytes32 packetId;
        uint256 proposalCount;
        bytes32 root;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to execute a packet.
     * @param executionDetails The execution details.
     * @param messageDetails The message details of the packet.
     */
    struct ExecuteRequest {
        ISocket.ExecutionDetails executionDetails;
        ISocket.MessageDetails messageDetails;
    }

    /**
     * @notice A struct representing a request to initiate an Arbitrum native transaction.
     * @param packetId The ID of the packet to be executed.
     * @param maxSubmissionCost The maximum submission cost of the transaction.
     * @param maxGas The maximum amount of gas for the transaction.
     * @param gasPriceBid The gas price bid for the transaction.
     * @param callValue The call value of the transaction.
     */
    struct ArbitrumNativeInitiatorRequest {
        bytes32 packetId;
        uint256 maxSubmissionCost;
        uint256 maxGas;
        uint256 gasPriceBid;
        uint256 callValue;
    }

    /**
     * @notice A struct representing a request to send proof to polygon root
     * @param proof proof to submit on root tunnel
     */
    struct ReceivePacketProofRequest {
        bytes proof;
    }

    /**
     * @notice A struct representing a request set fees in switchboard
     * @param nonce The nonce of fee setter address
     * @param dstChainSlug The sibling chain identifier
     * @param switchboardFees The fees needed by switchboard
     * @param verificationOverheadFees The fees needed for calling allowPacket while executing
     * @param signature The signature of the packet data.
     */
    struct SwitchboardSetFeesRequest {
        uint256 nonce;
        uint32 dstChainSlug;
        uint128 switchboardFees;
        uint128 verificationOverheadFees;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to set fees in execution manager and transmit manager
     * @param nonce The nonce of fee setter address
     * @param dstChainSlug The sibling chain identifier
     * @param fees The total fees needed
     * @param signature The signature of the packet data.
     */
    struct SetFeesRequest {
        uint256 nonce;
        uint32 dstChainSlug;
        uint128 fees;
        bytes signature;
        bytes4 functionSelector;
    }

    event FailedLogBytes(bytes reason);
    event FailedLog(string reason);
    event AllowlistUpdated(address indexed newAllowlist, bool indexed value);

    error AddressNotAllowed(address address_);
    
    /**
     * @notice sets fees in batch for switchboards
     * @param contractAddress_ address of contract to set fees
     * @param switchboardSetFeesRequest_ the list of requests
     */
    function setFeesBatch(
        address contractAddress_,
        SwitchboardSetFeesRequest[] calldata switchboardSetFeesRequest_
    ) external {
        uint256 executeRequestLength = switchboardSetFeesRequest_.length;
        for (uint256 index = 0; index < executeRequestLength; ) {
            FastSwitchboard(contractAddress_).setFees(
                switchboardSetFeesRequest_[index].nonce,
                switchboardSetFeesRequest_[index].dstChainSlug,
                switchboardSetFeesRequest_[index].switchboardFees,
                switchboardSetFeesRequest_[index].verificationOverheadFees,
                switchboardSetFeesRequest_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice sets fees in batch for transmit manager
     * @param contractAddress_ address of contract to set fees
     * @param setFeesRequests_ the list of requests
     */
    function setTransmissionFeesBatch(
        address contractAddress_,
        SetFeesRequest[] calldata setFeesRequests_
    ) external {
        uint256 feeRequestLength = setFeesRequests_.length;
        for (uint256 index = 0; index < feeRequestLength; ) {
            ITransmitManager(contractAddress_).setTransmissionFees(
                setFeesRequests_[index].nonce,
                setFeesRequests_[index].dstChainSlug,
                setFeesRequests_[index].fees,
                setFeesRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice sets fees in batch for execution manager
     * @param contractAddress_ address of contract to set fees
     * @param setFeesRequests_ the list of requests
     */
    function setExecutionFeesBatch(
        address contractAddress_,
        SetFeesRequest[] calldata setFeesRequests_
    ) external {
        uint256 feeRequestLength = setFeesRequests_.length;
        for (uint256 index = 0; index < feeRequestLength; ) {
            if (
                setFeesRequests_[index].functionSelector ==
                IExecutionManager.setExecutionFees.selector
            )
                IExecutionManager(contractAddress_).setExecutionFees(
                    setFeesRequests_[index].nonce,
                    setFeesRequests_[index].dstChainSlug,
                    setFeesRequests_[index].fees,
                    setFeesRequests_[index].signature
                );

            if (
                setFeesRequests_[index].functionSelector ==
                IExecutionManager.setRelativeNativeTokenPrice.selector
            )
                IExecutionManager(contractAddress_).setRelativeNativeTokenPrice(
                    setFeesRequests_[index].nonce,
                    setFeesRequests_[index].dstChainSlug,
                    setFeesRequests_[index].fees,
                    setFeesRequests_[index].signature
                );

            if (
                setFeesRequests_[index].functionSelector ==
                IExecutionManager.setMsgValueMaxThreshold.selector
            )
                IExecutionManager(contractAddress_).setMsgValueMaxThreshold(
                    setFeesRequests_[index].nonce,
                    setFeesRequests_[index].dstChainSlug,
                    setFeesRequests_[index].fees,
                    setFeesRequests_[index].signature
                );

            if (
                setFeesRequests_[index].functionSelector ==
                IExecutionManager.setMsgValueMinThreshold.selector
            )
                IExecutionManager(contractAddress_).setMsgValueMinThreshold(
                    setFeesRequests_[index].nonce,
                    setFeesRequests_[index].dstChainSlug,
                    setFeesRequests_[index].fees,
                    setFeesRequests_[index].signature
                );

            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice seal a batch of packets from capacitor on sourceChain mentioned in sealRequests
     * @param socketAddress_ address of socket
     * @param sealRequests_ the list of requests with packets to be sealed on sourceChain
     */
    function _sealBatch(
        address socketAddress_,
        SealRequest[] calldata sealRequests_
    ) internal {
        uint256 sealRequestLength = sealRequests_.length;
        for (uint256 index = 0; index < sealRequestLength; ) {
            ISocket(socketAddress_).seal(
                sealRequests_[index].batchSize,
                sealRequests_[index].capacitorAddress,
                sealRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice seal a batch of packets from capacitor on sourceChain mentioned in sealRequests
     * @param socketAddress_ address of socket
     * @param sealRequests_ the list of requests with packets to be sealed on sourceChain
     */
    function sealBatch(
        address socketAddress_,
        SealRequest[] calldata sealRequests_
    ) external onlyRole(SOCKET_RELAYER_ROLE) {
        _sealBatch(socketAddress_, sealRequests_);
    }

    /**
     * @notice propose a batch of packets sequentially by socketDestination
     * @param socketAddress_ address of socket
     * @param proposeRequests_ the list of requests with packets to be proposed by socketDestination
     */
    function _proposeBatch(
        address socketAddress_,
        ProposeRequest[] calldata proposeRequests_
    ) internal {
        uint256 proposeRequestLength = proposeRequests_.length;
        for (uint256 index = 0; index < proposeRequestLength; ) {
            ISocket(socketAddress_).proposeForSwitchboard(
                proposeRequests_[index].packetId,
                proposeRequests_[index].root,
                proposeRequests_[index].switchboard,
                proposeRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice propose a batch of packets sequentially by socketDestination
     * @param socketAddress_ address of socket
     * @param proposeRequests_ the list of requests with packets to be proposed by socketDestination
     */
    function proposeBatch(
        address socketAddress_,
        ProposeRequest[] calldata proposeRequests_
    ) external onlyRole(SOCKET_RELAYER_ROLE) {
        _proposeBatch(socketAddress_, proposeRequests_);
    }

    /**
     * @notice attests a batch of Packets
     * @param attestRequests_ the list of requests with packets to be attested by switchboard in sequence
     */
    function _attestBatch(AttestRequest[] calldata attestRequests_) internal {
        uint256 attestRequestLength = attestRequests_.length;
        for (uint256 index = 0; index < attestRequestLength; ) {
            FastSwitchboard(attestRequests_[index].switchboard).attest(
                attestRequests_[index].packetId,
                attestRequests_[index].proposalCount,
                attestRequests_[index].root,
                attestRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice attests a batch of Packets
     * @param attestRequests_ the list of requests with packets to be attested by switchboard in sequence
     */
    function attestBatch(AttestRequest[] calldata attestRequests_) external {
        _attestBatch(attestRequests_);
    }

    /**
     * @notice send a batch of propose, attest and execute transactions
     * @param socketAddress_ address of socket
     * @param proposeRequests_ the list of requests with packets to be proposed
     * @param attestRequests_ the list of requests with packets to be attested by switchboard
     * @param executeRequests_ the list of requests with messages to be executed
     */
    function sendBatch(
        address socketAddress_,
        SealRequest[] calldata sealRequests_,
        ProposeRequest[] calldata proposeRequests_,
        AttestRequest[] calldata attestRequests_,
        ExecuteRequest[] calldata executeRequests_
    ) external payable onlyRole(SOCKET_RELAYER_ROLE) {
        _sealBatch(socketAddress_, sealRequests_);
        _proposeBatch(socketAddress_, proposeRequests_);
        _attestBatch(attestRequests_);
        _executeBatch(socketAddress_, executeRequests_);
    }

    /**
     * @notice trip a batch of Proposals
     * @param proposalTripRequests_ the list of requests for tripping proposals
     */
    function proposalTripBatch(
        ProposalTripRequest[] calldata proposalTripRequests_
    ) external {
        uint256 proposalTripRequestLength = proposalTripRequests_.length;
        for (uint256 index = 0; index < proposalTripRequestLength; ) {
            try
                FastSwitchboard(proposalTripRequests_[index].switchboard)
                    .tripProposal(
                        proposalTripRequests_[index].nonce,
                        proposalTripRequests_[index].packetId,
                        proposalTripRequests_[index].proposalCount,
                        proposalTripRequests_[index].signature
                    )
            {} catch Error(string memory reason) {
                // catch failing revert() and require()
                emit FailedLog(reason);
            } catch (bytes memory reason) {
                // catch failing assert()
                emit FailedLogBytes(reason);
            }

            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice executes a batch of messages
     * @param socketAddress_ address of socket
     * @param executeRequests_ the list of requests with messages to be executed in sequence
     */
    function _executeBatch(
        address socketAddress_,
        ExecuteRequest[] calldata executeRequests_
    ) internal {
        uint256 executeRequestLength = executeRequests_.length;
        uint256 totalMsgValue = msg.value;
        for (uint256 index = 0; index < executeRequestLength; ) {
            bytes32 executionParams = executeRequests_[index]
                .messageDetails
                .executionParams;
            uint8 paramType = uint8(uint256(executionParams) >> 248);
            uint256 msgValue = uint256(uint248(uint256(executionParams)));

            if (paramType == 0) {
                msgValue = 0;
            } else totalMsgValue -= msgValue;

            ISocket(socketAddress_).execute{value: msgValue}(
                executeRequests_[index].executionDetails,
                executeRequests_[index].messageDetails
            );
            unchecked {
                ++index;
            }
        }

        if (totalMsgValue > 0) {
            SafeTransferLib.safeTransferETH(msg.sender, totalMsgValue);
        }
    }

    /**
     * @notice executes a batch of messages
     * @param socketAddress_ address of socket
     * @param executeRequests_ the list of requests with messages to be executed in sequence
     */
    function executeBatch(
        address socketAddress_,
        ExecuteRequest[] calldata executeRequests_
    ) external payable onlyRole(SOCKET_RELAYER_ROLE) {
        _executeBatch(socketAddress_, executeRequests_);
    }

    /**
     * @notice invoke receive Message on PolygonRootReceiver for a batch of messages in loop
     * @param polygonRootReceiverAddress_ address of polygonRootReceiver
     * @param receivePacketProofs_ the list of receivePacketProofs to be sent to receiveHook of polygonRootReceiver
     */
    function receiveMessageBatch(
        address polygonRootReceiverAddress_,
        ReceivePacketProofRequest[] calldata receivePacketProofs_
    ) external onlyRole(SOCKET_RELAYER_ROLE) {
        uint256 receivePacketProofsLength = receivePacketProofs_.length;
        for (uint256 index = 0; index < receivePacketProofsLength; ) {
            INativeRelay(polygonRootReceiverAddress_).receiveMessage(
                receivePacketProofs_[index].proof
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice returns latest proposalCounts for list of packetIds
     * @param socketAddress_ address of socket
     * @param packetIds_ the list of packetIds
     */
    function getProposalCountBatch(
        address socketAddress_,
        bytes32[] calldata packetIds_
    ) external view returns (uint256[] memory) {
        uint256 packetIdsLength = packetIds_.length;

        uint256[] memory proposalCounts = new uint256[](packetIdsLength);

        for (uint256 index = 0; index < packetIdsLength; ) {
            uint256 proposalCount = ISocket(socketAddress_).proposalCount(
                packetIds_[index]
            );
            proposalCounts[index] = proposalCount;
            unchecked {
                ++index;
            }
        }
        return proposalCounts;
    }

    /**
     * @notice returns root for capacitorAddress and count
     * @param capacitorAddresses_ addresses of capacitor
     * @param packetCounts_ the list of packetCounts
     */
    function getPacketRootBatch(
        address[] calldata capacitorAddresses_,
        uint64[] calldata packetCounts_
    ) external view returns (bytes32[] memory) {
        uint256 capacitorAddressesLength = capacitorAddresses_.length;

        bytes32[] memory packetRoots = new bytes32[](capacitorAddressesLength);

        for (uint256 index = 0; index < capacitorAddressesLength; ) {
            packetRoots[index] = ICapacitor(capacitorAddresses_[index])
                .getRootByCount(packetCounts_[index]);
            unchecked {
                ++index;
            }
        }
        return packetRoots;
    }

    /**
     * @notice initiate NativeConfirmation on arbitrumChain for a batch of packets in loop
     * @param switchboardAddress_ address of nativeArbitrumSwitchboard
     * @param arbitrumNativeInitiatorRequests_ the list of requests with packets to initiate nativeConfirmation on switchboard of arbitrumChain
     */
    function initiateArbitrumNativeBatch(
        address switchboardAddress_,
        address callValueRefundAddress_,
        address remoteRefundAddress_,
        ArbitrumNativeInitiatorRequest[]
            calldata arbitrumNativeInitiatorRequests_
    ) external payable onlyRole(SOCKET_RELAYER_ROLE) {
        uint256 arbitrumNativeInitiatorRequestsLength = arbitrumNativeInitiatorRequests_
                .length;
        uint256 totalMsgValue = msg.value;

        for (
            uint256 index = 0;
            index < arbitrumNativeInitiatorRequestsLength;

        ) {
            totalMsgValue -= arbitrumNativeInitiatorRequests_[index].callValue;
            INativeRelay(switchboardAddress_).initiateNativeConfirmation{
                value: arbitrumNativeInitiatorRequests_[index].callValue
            }(
                arbitrumNativeInitiatorRequests_[index].packetId,
                arbitrumNativeInitiatorRequests_[index].maxSubmissionCost,
                arbitrumNativeInitiatorRequests_[index].maxGas,
                arbitrumNativeInitiatorRequests_[index].gasPriceBid,
                callValueRefundAddress_,
                remoteRefundAddress_
            );
            unchecked {
                ++index;
            }
        }

        if (totalMsgValue > 0) {
            if (callValueRefundAddress_ == address(0)) revert ZeroAddress();
            SafeTransferLib.safeTransferETH(
                callValueRefundAddress_,
                totalMsgValue
            );
        }
    }

    /**
     * @notice initiate NativeConfirmation on nativeChain(s) for a batch of packets in loop
     * @param switchboardAddress_ address of nativeSwitchboard
     * @param nativePacketIds_ the list of requests with packets to initiate nativeConfirmation on switchboard of native chains
     */
    function initiateNativeBatch(
        address switchboardAddress_,
        bytes32[] calldata nativePacketIds_
    ) external onlyRole(SOCKET_RELAYER_ROLE) {
        uint256 nativePacketIdsLength = nativePacketIds_.length;
        for (uint256 index = 0; index < nativePacketIdsLength; ) {
            INativeRelay(switchboardAddress_).initiateNativeConfirmation(
                nativePacketIds_[index]
            );
            unchecked {
                ++index;
            }
        }
    }

    // RELAYER UTILITY FUNCTIONS

    /**
     * @notice Updates the allowlist
     * @param address_ The address to update
     * @param value_ The value to set
     */
    function updateAllowlist(address address_, bool value_) external onlyOwner {
        allowlist[address_] = value_;
        emit AllowlistUpdated(address_, value_);
    }
    
    /**
     * @notice Withdraws funds to multiple addresses
     * @param addresses The list of addresses to withdraw to
     * @param amounts The list of amounts to withdraw
     * @dev can only be called by addresses with the SOCKET_RELAYER_ROLE
     * can only withdraw to addresses in the allowlist
     */
    function withdrawals(
        address payable[] memory addresses,
        uint[] memory amounts
    ) public payable onlyRole(SOCKET_RELAYER_ROLE) {
        uint256 totalAmount;
        for (uint i; i < addresses.length; i++) {
            if (!allowlist[addresses[i]]) revert AddressNotAllowed(addresses[i]);
            totalAmount += amounts[i];
            addresses[i].transfer(amounts[i]);
        }

        require(totalAmount == msg.value, "LOW_MSG_VALUE");
    }

    /**
    @dev Check the token balance of a wallet in a token contract
    Returns the balance of the token for user. Avoids possible errors:
      - return 0 on non-contract address
    **/
    function balanceOf(
        address user,
        address token
    ) public view returns (uint256) {
        if (token == MOCK_ETH_ADDRESS) {
            return user.balance; // ETH balance
        } else {
            // check if token is actually a contract
            uint256 size;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                size := extcodesize(token)
            }
            if (size > 0) {
                return IERC20(token).balanceOf(user);
            }
        }
        revert("INVALID_TOKEN");
    }

    /**
     * @notice Fetches, for a list of _users and _tokens (ETH included with mock address), the balances
     * @param users The list of users
     * @param tokens The list of tokens
     * @return And array with the concatenation of, for each user, his/her balances
     **/
    function batchBalanceOf(
        address[] calldata users,
        address[] calldata tokens
    ) external view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](users.length * tokens.length);

        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                balances[i * tokens.length + j] = balanceOf(
                    users[i],
                    tokens[j]
                );
            }
        }

        return balances;
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, rescueTo_, amount_);
    }
}
