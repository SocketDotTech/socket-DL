// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

// import "../src/notaries/native-bridge/ArbitrumReceiver.sol";
// import "../src/accumulators/native-bridge/arbitrum/ArbitrumL1Accum.sol";

// import "../src/Socket.sol";
// import "../src/interfaces/native-bridge/IArbSys.sol";

contract ContractTest is Test {
    address constant sender = 0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa;
    address constant notary = 0xE0D31cba148BFa4A459f2E0FdD2d3f6d7EDd4B1F;
    address constant socket = 0xfc2140e9A83693CBd8b54C42AFf83ecb627c2Ec7;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("CHAIN2_RPC_URL"));
        vm.selectFork(fork);
    }

    function _getPacketId(
        uint256 packetCount_
    ) internal view returns (uint256 packetId) {
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

    uint256[] abc;

    function testSimulate() public {
        vm.prank(sender);

        abc.push(543901034878720);
        abc.push(52363);
        abc.push(100000000);
        // ArbitrumL1Accum(0x818C8977Eed2Dd55A591672e18c9446090057881).sealPacket{
        //     value: 0x0e821d224f2980
        // }(abc);
        // ArbitrumReceiver(0xEa0814C572cDD329380ddf345463E3fb7E342a93).attest(
        //     148442832523846428096205353516622632451036763875884702874094471741441,
        //     0xa7f19d9430552a67c037c6188fa97b2544b5f41f313e908b2781f2da731f0e52,
        //     bytes("")
        // );
    }
}
