// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/Verifier.sol";
import "../src/utils/SignatureVerifier.sol";
import "../src/utils/Hasher.sol";
import "../src/plugs/Vault.sol";

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
    uint256 internal _msgGasLimit = 120000;

    bool constant _isFast = false;
    string _name = "Socket Gas Token";
    string _symbol = "SGT";

    struct ChainContext {
        uint256 chainId;
        AdminNotary notary__;
        Hasher hasher__;
        IAccumulator accum__;
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

    function _dualChainSetup(uint256[] memory attesters_) internal {
        _a.chainId = 0x2013AA263;
        _b.chainId = 0x2013AA264;

        _a = _deployContractsOnSingleChain(_a.chainId, _b.chainId);
        _b = _deployContractsOnSingleChain(_b.chainId, _a.chainId);

        _addAttesters(attesters_, _a, _b.chainId);
        _addAttesters(attesters_, _b, _a.chainId);

        _initVerifier(_a, _b.chainId);
        _initVerifier(_b, _a.chainId);
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

    function _initVerifier(ChainContext memory cc_, uint256 destChainId_)
        internal
    {
        // add pausers
        hoax(_plugOwner);
        cc_.verifier__.addPauser(_pauser, destChainId_);

        // activate remote chains
        hoax(_pauser);
        cc_.verifier__.activate(destChainId_);
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
            address(cc.notary__),
            cc.chainId,
            _socketOwner
        );

        (cc.accum__, cc.deaccum__) = _deployAccumDeaccum(
            cc.notary__,
            address(cc.socket__),
            _socketOwner,
            destChainId_,
            _isFast
        );

        hoax(_socketOwner);
        cc.verifier__ = new Verifier(
            address(cc.socket__),
            _plugOwner,
            address(cc.notary__),
            _timeoutInSeconds
        );
    }

    function _deploySocket(
        address notary_,
        uint256 chainId_,
        address deployer_
    )
        internal
        returns (
            Hasher hasher__,
            Vault vault__,
            Socket socket__
        )
    {
        vm.startPrank(deployer_);
        hasher__ = new Hasher();
        vault__ = new Vault(_name, _symbol, deployer_, notary_);
        socket__ = new Socket(chainId_, address(hasher__), address(vault__));

        vault__.setSocket(address(socket__));
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
        uint256 destChainId_,
        bool isFast_
    ) internal returns (SingleAccum accum__, SingleDeaccum deaccum__) {
        vm.startPrank(deployer_);

        accum__ = new SingleAccum(socket_, address(notary__));
        deaccum__ = new SingleDeaccum();

        notary__.addAccumulator(address(accum__), destChainId_, isFast_);

        vm.stopPrank();
    }

    function _getLatestSignature(ChainContext storage src_)
        internal
        returns (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        )
    {
        (root, packetId) = src_.accum__.getNextPacket();
        bytes32 digest = keccak256(
            abi.encode(src_.chainId, address(src_.accum__), packetId, root)
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

    function _verifyAndSealOnSrc(
        ChainContext storage src_,
        ChainContext storage dest_,
        bytes memory sig_
    ) internal {
        hoax(_attester);
        src_.notary__.verifyAndSeal(address(src_.accum__), dest_.chainId, sig_);
    }

    function _submitRootOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        bytes memory sig_,
        uint256 packetId_,
        bytes32 root_
    ) internal {
        hoax(_raju);
        dst_.notary__.propose(
            src_.chainId,
            address(src_.accum__),
            packetId_,
            root_,
            sig_
        );
    }

    function _executePayloadOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        address destPlug_,
        uint256 packetId_,
        uint256 msgId_,
        uint256 msgGasLimit_,
        bytes memory payload_,
        bytes memory proof_
    ) internal {
        hoax(_raju);

        ISocket.ExecuteParams memory params = ISocket.ExecuteParams(
            src_.chainId,
            destPlug_,
            msgId_,
            address(src_.accum__),
            packetId_,
            msgGasLimit_,
            payload_,
            proof_
        );

        dst_.socket__.execute(params);
    }
}
