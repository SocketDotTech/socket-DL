// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/AcceptWithTimeout.sol";
import "../src/examples/counter.sol";

contract HappyTest is Test {
    address constant _socketOwner = address(1);
    address constant _counterOwner = address(2);
    uint256 constant _signerPrivateKey = uint256(3);
    address _signer;
    address constant _raju = address(4);
    address constant _pauser = address(5);

    uint256 constant _minBondAmount = 100e18;
    uint256 constant _bondClaimDelay = 1 weeks;
    uint256 constant _chainId_A = 0x2013AA263;
    uint256 constant _chainId_B = 0x2013AA264;

    ISocket _socket_A__;
    ISocket _socket_B__;

    SingleAccum _accum_A__;
    SingleAccum _accum_B__;

    SingleDeaccum _deaccum_A__;
    SingleDeaccum _deaccum_B__;

    AcceptWithTimeout _verifier_A__;
    AcceptWithTimeout _verifier_B__;

    Counter _counter_A__;
    Counter _counter_B__;

    function setUp() external {
        _signer = vm.addr(_signerPrivateKey);

        _socket_A__ = new Socket(_minBondAmount, _bondClaimDelay, _chainId_A);
        _socket_B__ = new Socket(_minBondAmount, _bondClaimDelay, _chainId_B);

        _accum_A__ = new SingleAccum(address(_socket_A__));
        _accum_B__ = new SingleAccum(address(_socket_B__));

        _deaccum_A__ = new SingleDeaccum();
        _deaccum_B__ = new SingleDeaccum();

        _verifier_A__ = new AcceptWithTimeout(
            0,
            address(_socket_A__),
            _counterOwner
        );
        _verifier_B__ = new AcceptWithTimeout(
            0,
            address(_socket_B__),
            _counterOwner
        );

        hoax(_signer);
        _socket_A__.addBond{value: _minBondAmount}();
        hoax(_signer);
        _socket_B__.addBond{value: _minBondAmount}();

        _counter_A__ = new Counter(address(_socket_A__));
        _counter_B__ = new Counter(address(_socket_B__));

        hoax(_counterOwner);
        _counter_A__.setSocketConfig(
            _chainId_B,
            address(_counter_B__),
            address(_accum_A__),
            address(_deaccum_A__),
            address(_verifier_A__)
        );

        hoax(_counterOwner);
        _counter_B__.setSocketConfig(
            _chainId_A,
            address(_counter_A__),
            address(_accum_B__),
            address(_deaccum_B__),
            address(_verifier_B__)
        );
    }

    function remoteAddFromAtoB() external {}
}
