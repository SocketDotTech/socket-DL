// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    uint256 immutable remoteChainSlug = uint32(uint256(2));
    uint256 immutable packetId = 1;

    FastSwitchboard fastSwitchboard;

    function setUp() external {
        _a.chainSlug = uint32(uint256(1));

        vm.startPrank(_socketOwner);

        fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            _timeoutInSeconds
        );

        fastSwitchboard.setExecutionOverhead(
            remoteChainSlug,
            _executionOverhead
        );
        fastSwitchboard.grantWatcherRole(
            remoteChainSlug,
            vm.addr(_watcherPrivateKey)
        );
        fastSwitchboard.grantWatcherRole(
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );

        fastSwitchboard.setAttestGasLimit(remoteChainSlug, _attestGasLimit);
        vm.stopPrank();
    }

    function testAttest() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));

        bytes memory sig = _createSignature(digest, _watcherPrivateKey);
        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        assertTrue(
            fastSwitchboard.isAttested(vm.addr(_watcherPrivateKey), packetId)
        );
    }
}
