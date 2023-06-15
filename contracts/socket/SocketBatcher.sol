// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControl.sol";

import {ISocket} from "../interfaces/ISocket.sol";
import {ITransmitManager} from "../interfaces/ITransmitManager.sol";
import {IExecutionManager} from "../interfaces/IExecutionManager.sol";

import {FastSwitchboard} from "../switchboard/default-switchboards/FastSwitchboard.sol";
import {INativeRelay} from "../interfaces/INativeRelay.sol";

import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title SocketBatcher
 * @notice A contract that facilitates the batching of packets across chains. It manages requests for sealing, proposing, attesting, and executing packets across multiple chains.
 * It also has functions for setting gas limits, execution overhead, and registering switchboards.
 * @dev This contract uses the AccessControl contract for managing role-based access control.
 */
contract SocketBatcher is AccessControl {
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
     * @notice A struct representing an attestation request for a packet.
     * @param packetId The ID of the packet being attested.
     * @param srcChainSlug The slug of the source chain.
     * @param signature The signature of the packet data.
     */
    struct AttestRequest {
        bytes32 packetId;
        uint256 proposalCount;
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
     * @param verificationFees The fees needed for calling allowPacket while executing
     * @param signature The signature of the packet data.
     */
    struct SwitchboardSetFeesRequest {
        uint256 nonce;
        uint32 dstChainSlug;
        uint128 switchboardFees;
        uint128 verificationFees;
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

    /**
     * @notice sets fees in batch for switchboards
     * @param contractAddress_ address of contract to set fees
     * @param switchboardSetFeesRequest_ the list of requests
     */
    function setFeesBatch(
        address contractAddress_,
        SwitchboardSetFeesRequest[] calldata switchboardSetFeesRequest_
    ) external {
        uint256 executeRequestslength = switchboardSetFeesRequest_.length;
        for (uint256 index = 0; index < executeRequestslength; ) {
            FastSwitchboard(contractAddress_).setFees(
                switchboardSetFeesRequest_[index].nonce,
                switchboardSetFeesRequest_[index].dstChainSlug,
                switchboardSetFeesRequest_[index].switchboardFees,
                switchboardSetFeesRequest_[index].verificationFees,
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
        uint256 executeRequestslength = setFeesRequests_.length;
        for (uint256 index = 0; index < executeRequestslength; ) {
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
        uint256 executeRequestslength = setFeesRequests_.length;
        for (uint256 index = 0; index < executeRequestslength; ) {
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
    function sealBatch(
        address socketAddress_,
        SealRequest[] calldata sealRequests_
    ) external {
        uint256 sealRequestslength = sealRequests_.length;
        for (uint256 index = 0; index < sealRequestslength; ) {
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
     * @notice propose a batch of packets sequentially by socketDestination
     * @param socketAddress_ address of socket
     * @param proposeRequests_ the list of requests with packets to be proposed by socketDestination
     */
    function proposeBatch(
        address socketAddress_,
        ProposeRequest[] calldata proposeRequests_
    ) external {
        uint256 proposeRequestslength = proposeRequests_.length;
        for (uint256 index = 0; index < proposeRequestslength; ) {
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
     * @notice attests a batch of Packets
     * @param switchBoardAddress_ address of switchboard
     * @param attestRequests_ the list of requests with packets to be attested by switchboard in sequence
     */
    function attestBatch(
        address switchBoardAddress_,
        AttestRequest[] calldata attestRequests_
    ) external {
        uint256 attestRequestslength = attestRequests_.length;
        for (uint256 index = 0; index < attestRequestslength; ) {
            FastSwitchboard(switchBoardAddress_).attest(
                attestRequests_[index].packetId,
                attestRequests_[index].proposalCount,
                attestRequests_[index].signature
            );
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
    function executeBatch(
        address socketAddress_,
        ExecuteRequest[] calldata executeRequests_
    ) external payable {
        uint256 executeRequestslength = executeRequests_.length;
        for (uint256 index = 0; index < executeRequestslength; ) {
            bytes32 executionParams = executeRequests_[index]
                .messageDetails
                .executionParams;
            uint8 paramType = uint8(uint256(executionParams) >> 248);
            uint256 msgValue = uint256(uint248(uint256(executionParams)));
            if (paramType == 0) msgValue = 0;

            ISocket(socketAddress_).execute{value: msgValue}(
                executeRequests_[index].executionDetails,
                executeRequests_[index].messageDetails
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice invoke receieve Message on PolygonRootReceiver for a batch of messages in loop
     * @param polygonRootReceiverAddress_ address of polygonRootReceiver
     * @param receivePacketProofs_ the list of receivePacketProofs to be sent to receiveHook of polygonRootReceiver
     */
    function receiveMessageBatch(
        address polygonRootReceiverAddress_,
        ReceivePacketProofRequest[] calldata receivePacketProofs_
    ) external {
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
    ) external payable {
        uint256 arbitrumNativeInitiatorRequestsLength = arbitrumNativeInitiatorRequests_
                .length;
        for (
            uint256 index = 0;
            index < arbitrumNativeInitiatorRequestsLength;

        ) {
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

        if (address(this).balance > 0)
            callValueRefundAddress_.call{value: address(this).balance}("");
    }

    /**
     * @notice initiate NativeConfirmation on nativeChain(s) for a batch of packets in loop
     * @param switchboardAddress_ address of nativeSwitchboard
     * @param nativePacketIds_ the list of requests with packets to initiate nativeConfirmation on switchboard of native chains
     */
    function initiateNativeBatch(
        address switchboardAddress_,
        bytes32[] calldata nativePacketIds_
    ) external {
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

    /**
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
