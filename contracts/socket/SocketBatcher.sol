// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControlExtended.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {FastSwitchboard} from "../switchboard/default-switchboards/FastSwitchboard.sol";

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

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
