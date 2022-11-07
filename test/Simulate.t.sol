// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "../src/notaries/AdminNotary.sol";
import "../src/Socket.sol";
import "../src/interfaces/native-bridge/IArbSys.sol";

contract ContractTest is Test {
    address constant sender = 0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa;
    address constant notary = 0xe63Bc038f4bE3aF3efC6318e3CAc39F60d700526;
    address constant socket = 0xfc2140e9A83693CBd8b54C42AFf83ecb627c2Ec7;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("ARBITRUM_RPC"));
        vm.selectFork(fork);
    }

    function _getPacketId(uint256 packetCount_)
        internal
        view
        returns (uint256 packetId)
    {
        packetId =
            (uint256(412613) << 224) |
            (uint256(
                uint160(address(0x03D51955216a7E6F301e0613515fA86A6f3d59A9))
            ) << 64) |
            packetCount_;

        // 0x00064bc5
        // 0x00066eed
        console.logBytes32(bytes32(packetId));
        console.logBytes32(
            bytes32(
                uint256(
                    11366664397778083202886441928765703501133598146671869957683323325632217088
                )
            )
        );
    }

    function testSimulate() public {
        vm.prank(sender);

        uint256[] memory ar = new uint256[](0);

        bytes memory data = abi.encodeWithSelector(
            INotary.attest.selector,
            _getPacketId(0),
            0x6b9aee2476cdac32a0d4fbb712c6844c979de18105316b64469af4ee03158c86,
            hex"3a8580bb634c7abd7d1d35d86cb5214732ff8b127907f3ee9b57537a76ac369707bf8f815dafaaa8991d6639720b2312e20863c67f7150378635f703967642161b"
        );
        // bytes("0x3a8580bb634c7abd7d1d35d86cb5214732ff8b127907f3ee9b57537a76ac369707bf8f815dafaaa8991d6639720b2312e20863c67f7150378635f703967642161b");
        IArbSys(address(100)).sendTxToL1(
            0xEd7f855da2609ede9659709612a743E8b415F9D2,
            data
        );
        AdminNotary(notary).seal(
            0x03D51955216a7E6F301e0613515fA86A6f3d59A9,
            ar,
            hex"3a8580bb634c7abd7d1d35d86cb5214732ff8b127907f3ee9b57537a76ac369707bf8f815dafaaa8991d6639720b2312e20863c67f7150378635f703967642161b"
        );
    }
}

// 0x4ecfb3370006
// 4bc5
// 03d51955216a7e6f301e0613515fa86a6f3d59a900000000000000006b9aee2476cdac32a0d4fbb712c6844c979de18105316b64469af4ee03158c86000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000413a8580bb634c7abd7d1d35d86cb5214732ff8b127907f3ee9b57537a76ac369707bf8f815dafaaa8991d6639720b2312e20863c67f7150378635f703967642161b00000000000000000000000000000000000000000000000000000000000000
// 0x4ecfb3370006
// 6eed
// 03d51955216a7e6f301e0613515fa86a6f3d59a900000000000000006b9aee2476cdac32a0d4fbb712c6844c979de18105316b64469af4ee03158c86000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000413a8580bb634c7abd7d1d35d86cb5214732ff8b127907f3ee9b57537a76ac369707bf8f815dafaaa8991d6639720b2312e20863c67f7150378635f703967642161b00000000000000000000000000000000000000000000000000000000000000
