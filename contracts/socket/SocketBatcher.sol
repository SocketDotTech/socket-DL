// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControlExtended.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {FastSwitchboard} from "../switchboard/default-switchboards/FastSwitchboard.sol";
import {INativeRelay} from "../interfaces/INativeRelay.sol";

contract SocketBatcher is AccessControlExtended {
    constructor(address owner_) AccessControlExtended(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    struct SealRequest {
        uint256 batchSize;
        address capacitorAddress;
        bytes signature;
    }

    struct ProposeRequest {
        bytes32 packetId;
        bytes32 root;
        bytes signature;
    }

    struct AttestRequest {
        bytes32 packetId;
        uint256 srcChainSlug;
        bytes signature;
    }

    struct ExecuteRequest {
        bytes32 packetId;
        address localPlug;
        ISocket.MessageDetails messageDetails;
        bytes signature;
    }

    struct ArbitrumNativeInitiatorRequest {
        bytes32 packetId;
        uint256 maxSubmissionCost;
        uint256 maxGas;
        uint256 gasPriceBid;
    }

    struct NativeInitiatorRequest {
        bytes32 packetId;
    }

    struct PolygonReceiveMessageRequest {
        bytes receivePacketProof;
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
            ISocket(socketAddress_).propose(
                proposeRequests_[index].packetId,
                proposeRequests_[index].root,
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
                attestRequests_[index].srcChainSlug,
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
    ) external {
        uint256 executeRequestslength = executeRequests_.length;
        for (uint256 index = 0; index < executeRequestslength; ) {
            ISocket(socketAddress_).execute(
                executeRequests_[index].packetId,
                executeRequests_[index].localPlug,
                executeRequests_[index].messageDetails,
                executeRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    function receiveMessageBatch(
        address polygonRootReceiverAddress_,
        PolygonReceiveMessageRequest[] calldata polygonReceiveMessageRequests_
    ) external {
        uint256 receiveMessagesLength = polygonReceiveMessageRequests_.length;
        for (uint256 index = 0; index < receiveMessagesLength; ) {
            INativeRelay(polygonRootReceiverAddress_).receiveMessage(
                polygonReceiveMessageRequests_[index].receivePacketProof
            );
            unchecked {
                ++index;
            }
        }
    }

    function initiateArbitrumNativeBatch(
        address switchboardAddress_,
        ArbitrumNativeInitiatorRequest[]
            calldata arbitrumNativeInitiatorRequests_
    ) external {
        uint256 arbitrumNativeInitiatorRequestsLength = arbitrumNativeInitiatorRequests_
                .length;
        for (
            uint256 index = 0;
            index < arbitrumNativeInitiatorRequestsLength;

        ) {
            INativeRelay(switchboardAddress_).initiateNativeConfirmation(
                arbitrumNativeInitiatorRequests_[index].packetId,
                arbitrumNativeInitiatorRequests_[index].maxSubmissionCost,
                arbitrumNativeInitiatorRequests_[index].maxGas,
                arbitrumNativeInitiatorRequests_[index].gasPriceBid
            );
            unchecked {
                ++index;
            }
        }
    }

    function initiateNativeBatch(
        address switchboardAddress_,
        NativeInitiatorRequest[] calldata nativeInitiatorRequests_
    ) external {
        uint256 nativeInitiatorRequestsLength = nativeInitiatorRequests_.length;
        for (uint256 index = 0; index < nativeInitiatorRequestsLength; ) {
            INativeRelay(switchboardAddress_).initiateNativeConfirmation(
                nativeInitiatorRequests_[index].packetId
            );
            unchecked {
                ++index;
            }
        }
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
