// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/notaries/AdminNotary.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/Verifier.sol";
import "../src/utils/SignatureVerifier.sol";
import "../src/utils/Hasher.sol";
import "../src/vault/Vault.sol";

contract Setup is Test {
    address constant _socketOwner = address(1);
    address constant _plugOwner = address(2);
    address constant _raju = address(4);
    address constant _pauser = address(5);
    address _attester;
    address _altAttester;

    uint256 constant _attesterPrivateKey = uint256(1);
    uint256 constant _altAttesterPrivateKey = uint256(2);

    uint256 internal _timeoutInSeconds = 0;
    uint256 internal _slowAccumWaitTime = 300;
    uint256 internal _msgGasLimit = 25548;
    string internal fastAccumName = "FAST";
    string internal slowAccumName = "SLOW";

    struct ChainContext {
        uint256 chainId;
        uint256 slowAccumConfigId;
        uint256 fastAccumConfigId;
        AdminNotary notary__;
        Hasher hasher__;
        IAccumulator fastAccum__;
        IAccumulator slowAccum__;
        IDeaccumulator deaccum__;
        SignatureVerifier sigVerifier__;
        Socket socket__;
        Vault vault__;
        Verifier verifier__;
    }

    struct MessageContext {
        uint256 amount;
        uint256 msgId;
        bytes32 root;
        uint256 packetId;
        bytes sig;
        bytes payload;
        bytes proof;
    }

    ChainContext _a;
    ChainContext _b;

    function _dualChainSetup(uint256[] memory attesters_, uint256 minFees_)
        internal
    {
        _a.chainId = uint16(uint256(0x2013AA263));
        _b.chainId = uint16(uint256(0x2013AA264));

        _a = _deployContractsOnSingleChain(_a.chainId, _b.chainId);
        _b = _deployContractsOnSingleChain(_b.chainId, _a.chainId);

        // setup attesters
        _addAttesters(attesters_, _a, _b.chainId);
        _addAttesters(attesters_, _b, _a.chainId);

        // add fast and slow config for all destChains
        _setConfig(_a, _b.chainId);
        _setConfig(_b, _a.chainId);

        // setup minfees in vault for diff accum for all dest chains
        vm.startPrank(_socketOwner);
        _a.vault__.setFees(minFees_, _a.fastAccumConfigId);
        _a.vault__.setFees(minFees_, _a.slowAccumConfigId);
        _b.vault__.setFees(minFees_, _b.fastAccumConfigId);
        _b.vault__.setFees(minFees_, _b.slowAccumConfigId);
        vm.stopPrank();
    }

    function _addAttesters(
        uint256[] memory attesterPrivateKey_,
        ChainContext memory cc_,
        uint256 destChainId_
    ) internal {
        vm.startPrank(_socketOwner);

        address attester;
        for (uint256 index = 0; index < attesterPrivateKey_.length; index++) {
            // deduce attester address from private key
            attester = vm.addr(attesterPrivateKey_[index]);
            // grant attester role
            cc_.notary__.grantAttesterRole(destChainId_, attester);
        }

        vm.stopPrank();
    }

    function _deployContractsOnSingleChain(
        uint256 srcChainId_,
        uint256 destChainId_
    ) internal returns (ChainContext memory cc) {
        cc.chainId = srcChainId_;
        (cc.sigVerifier__, cc.notary__) = _deployNotary(
            cc.chainId,
            _socketOwner
        );

        (cc.hasher__, cc.vault__, cc.socket__) = _deploySocket(
            cc.chainId,
            _socketOwner
        );

        (cc.fastAccum__, cc.deaccum__) = _deployAccumDeaccum(
            cc.notary__,
            address(cc.socket__),
            _socketOwner,
            destChainId_
        );

        (cc.slowAccum__, cc.deaccum__) = _deployAccumDeaccum(
            cc.notary__,
            address(cc.socket__),
            _socketOwner,
            destChainId_
        );

        hoax(_socketOwner);
        cc.verifier__ = new Verifier(
            _plugOwner,
            address(cc.notary__),
            _timeoutInSeconds
        );

        hoax(_socketOwner);
        cc.socket__.grantExecutorRole(_raju);
    }

    function _setConfig(ChainContext storage cc_, uint256 destChainId_)
        internal
    {
        hoax(_socketOwner);
        cc_.fastAccumConfigId = cc_.socket__.addConfig(
            destChainId_,
            address(cc_.fastAccum__),
            address(cc_.deaccum__),
            address(cc_.verifier__),
            fastAccumName
        );

        hoax(_socketOwner);
        cc_.slowAccumConfigId = cc_.socket__.addConfig(
            destChainId_,
            address(cc_.slowAccum__),
            address(cc_.deaccum__),
            address(cc_.verifier__),
            slowAccumName
        );
    }

    function _deploySocket(uint256 chainId_, address deployer_)
        internal
        returns (
            Hasher hasher__,
            Vault vault__,
            Socket socket__
        )
    {
        vm.startPrank(deployer_);
        hasher__ = new Hasher();
        vault__ = new Vault(deployer_);
        socket__ = new Socket(
            uint16(chainId_),
            address(hasher__),
            address(vault__)
        );

        vm.stopPrank();
    }

    function _deployNotary(uint256 chainId_, address deployer_)
        internal
        returns (SignatureVerifier sigVerifier__, AdminNotary notary__)
    {
        vm.startPrank(deployer_);
        sigVerifier__ = new SignatureVerifier();
        notary__ = new AdminNotary(address(sigVerifier__), chainId_);

        vm.stopPrank();
    }

    function _deployAccumDeaccum(
        AdminNotary notary__,
        address socket_,
        address deployer_,
        uint256 destChainId_
    ) internal returns (SingleAccum accum__, SingleDeaccum deaccum__) {
        vm.startPrank(deployer_);

        accum__ = new SingleAccum(socket_, address(notary__), destChainId_);
        deaccum__ = new SingleDeaccum();

        vm.stopPrank();
    }

    function _getLatestSignature(
        ChainContext storage src_,
        address accum_,
        uint256 destChainId_
    )
        internal
        returns (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        )
    {
        (root, packetId) = IAccumulator(accum_).getNextPacketToBeSealed();

        bytes32 digest = keccak256(
            abi.encode(src_.chainId, destChainId_, accum_, packetId, root)
        );
        digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _attesterPrivateKey,
            digest
        );
        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);

        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }

    function _sealOnSrc(
        ChainContext storage src_,
        address accum,
        bytes memory sig_
    ) internal {
        hoax(_attester);
        src_.notary__.seal(accum, sig_);
    }

    function _submitRootOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        bytes memory sig_,
        uint256 packetId_,
        bytes32 root_,
        address accum_
    ) internal {
        hoax(_raju);
        dst_.notary__.propose(src_.chainId, accum_, packetId_, root_, sig_);
    }

    function _executePayloadOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        address destPlug_,
        uint256 packetId_,
        uint256 msgId_,
        uint256 msgGasLimit_,
        address accum_,
        bytes memory payload_,
        bytes memory proof_
    ) internal {
        hoax(_raju);

        ISocket.VerificationParams memory vParams = ISocket.VerificationParams(
            src_.chainId,
            packetId_,
            accum_,
            proof_
        );

        dst_.socket__.execute(
            msgGasLimit_,
            msgId_,
            destPlug_,
            payload_,
            vParams
        );
    }

    function _packMessageId(
        address srcPlug,
        uint256 srcChainId,
        uint256 destChainId,
        uint256 nonce
    ) internal pure returns (uint256) {
        return
            (uint256(uint160(srcPlug)) << 96) |
            (srcChainId << 80) |
            (destChainId << 64) |
            nonce;
    }

    // to ignore this file from coverage
    function test() external {
        assertTrue(true);
    }
}
