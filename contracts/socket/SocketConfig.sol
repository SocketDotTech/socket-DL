// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISocket.sol";
import "../utils/AccessControl.sol";
import "../interfaces/ICapacitorFactory.sol";

interface ISwitchboard {}

abstract contract SocketConfig is ISocket, AccessControl(msg.sender) {
    struct PlugConfig {
        address siblingPlug;
        ICapacitor capacitor__;
        IDecapacitor decapacitor__;
        ISwitchboard inboundSwitchboard__;
        ISwitchboard outboundSwitchboard__;
    }

    ICapacitorFactory public _capacitorFactory__;

    // switchboard => ICapacitor
    mapping(address => ICapacitor) public _capacitors__;
    // switchboard => IDecapacitor
    mapping(address => IDecapacitor) public _decapacitors__;
    // switchboard => siblingChainSlug
    mapping(address => uint256) public _siblingChainSlugs;

    // plug => remoteChainSlug => config(verifiers, capacitors, decapacitors, remotePlug)
    mapping(address => mapping(uint256 => PlugConfig)) public _plugConfigs;

    event SwitchboardAdded(
        address switchboard,
        uint256 siblingChainSlug,
        address capacitor,
        address decapacitor
    );
    event PlugConnected(
        address plug,
        uint256 siblingChainSlug,
        address siblingPlug,
        address outboundSwitchboard,
        address inboundSwitchboar,
        address capacitor,
        address decapacitor
    );

    error SwitchboardExists();
    error InvalidSwitchboard();

    constructor(address capacitorFactory_) {
        _capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
    }

    // todo: need event, check for other such functions.
    function setCapacitorFactory(address capacitorFactory_) external onlyOwner {
        _capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
    }

    function registerSwitchBoard(
        address switchBoardAddress_,
        uint256 siblingChainSlug_,
        uint256 capacitorType_
    ) external {
        if (_capacitors__[switchBoardAddress_] != 0) revert SwitchboardExists();

        (
            ICapacitor capacitor__,
            IDecapacitor decapacitor__
        ) = _capacitorFactory__.deploy(capacitorType_, siblingChainSlug_);
        _capacitors__[switchBoardAddress_] = capacitor__;
        _decapacitors__[switchBoardAddress_] = decapacitor__;
        _siblingChainSlugs[switchBoardAddress_] = siblingChainSlug_;

        emit SwitchboardAdded(
            switchBoardAddress_,
            siblingChainSlug_,
            address(capacitor__),
            address(decapacitor__)
        );
    }

    function connect(
        uint256 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external {
        if (
            _capacitors__[inboundSwitchboard_] == 0 ||
            _capacitors__[outboundSwitchboard_] == 0 ||
            _siblingChainSlugs[inboundSwitchboard_] != siblingChainSlug_ ||
            _siblingChainSlugs[outboundSwitchboard_] != siblingChainSlug_
        ) revert InvalidSwitchboard();

        PlugConfig storage _plugConfig = _plugConfigs[msg.sender][
            siblingChainSlug_
        ];

        _plugConfig.siblingPlug = siblingPlug_;
        _plugConfig.capacitor__ = _capacitors__[outboundSwitchboard_];
        _plugConfig.decapacitor__ = _decapacitors__[inboundSwitchboard_];
        _plugConfig.inboundSwitchboard__ = ISwitchboard(inboundSwitchboard_);
        _plugConfig.outboundSwitchboard__ = ISwitchboard(outboundSwitchboard_);

        emit PlugConnected(
            msg.sender,
            siblingChainSlug_,
            siblingPlug_,
            outboundSwitchboard_,
            inboundSwitchboard_,
            address(_capacitors__[outboundSwitchboard_]),
            address(_decapacitors__[inboundSwitchboard_])
        );
    }
}
