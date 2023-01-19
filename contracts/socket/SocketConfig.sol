// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISocket.sol";
import "../utils/AccessControl.sol";
import "../interfaces/ICapacitorFactory.sol";
import "../interfaces/ISwitchboard.sol";

abstract contract SocketConfig is ISocket, AccessControl(msg.sender) {
    struct PlugConfig {
        address siblingPlug;
        ICapacitor capacitor__;
        IDecapacitor decapacitor__;
        ISwitchboard inboundSwitchboard__;
        ISwitchboard outboundSwitchboard__;
    }

    ICapacitorFactory public _capacitorFactory__;

    // siblingChainSlug => capacitor address
    mapping(address => uint256) public _capacitorToSlug;

    // switchboard => siblingChainSlug => ICapacitor
    mapping(address => mapping(uint256 => ICapacitor)) public _capacitors__;
    // switchboard => siblingChainSlug => IDecapacitor
    mapping(address => mapping(uint256 => IDecapacitor)) public _decapacitors__;

    // plug => remoteChainSlug => (siblingPlug, capacitor__, decapacitor__, inboundSwitchboard__, outboundSwitchboard__)
    mapping(address => mapping(uint256 => PlugConfig)) public _plugConfigs;

    event SwitchboardAdded(
        address switchboard,
        uint256 siblingChainSlug,
        address capacitor,
        address decapacitor
    );

    error SwitchboardExists();
    error InvalidConnection();

    // todo: need event, check for other such functions.
    function setCapacitorFactory(address capacitorFactory_) external onlyOwner {
        _capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
    }

    function registerSwitchBoard(
        address switchBoardAddress_,
        uint32 siblingChainSlug_,
        uint32 capacitorType_
    ) external {
        // only capacitor checked, decapacitor assumed will exist if capacitor does
        if (
            address(_capacitors__[switchBoardAddress_][siblingChainSlug_]) !=
            address(0)
        ) revert SwitchboardExists();

        (
            ICapacitor capacitor__,
            IDecapacitor decapacitor__
        ) = _capacitorFactory__.deploy(capacitorType_, siblingChainSlug_);

        _capacitorToSlug[address(capacitor__)] = siblingChainSlug_;
        _capacitors__[switchBoardAddress_][siblingChainSlug_] = capacitor__;
        _decapacitors__[switchBoardAddress_][siblingChainSlug_] = decapacitor__;

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
    ) external override {
        if (
            address(_capacitors__[inboundSwitchboard_][siblingChainSlug_]) ==
            address(0) ||
            address(_capacitors__[outboundSwitchboard_][siblingChainSlug_]) ==
            address(0)
        ) revert InvalidConnection();

        PlugConfig storage _plugConfig = _plugConfigs[msg.sender][
            siblingChainSlug_
        ];

        _plugConfig.siblingPlug = siblingPlug_;
        _plugConfig.capacitor__ = _capacitors__[outboundSwitchboard_][
            siblingChainSlug_
        ];
        _plugConfig.decapacitor__ = _decapacitors__[inboundSwitchboard_][
            siblingChainSlug_
        ];
        _plugConfig.inboundSwitchboard__ = ISwitchboard(inboundSwitchboard_);
        _plugConfig.outboundSwitchboard__ = ISwitchboard(outboundSwitchboard_);

        emit PlugConnected(
            msg.sender,
            siblingChainSlug_,
            _plugConfig.siblingPlug,
            address(_plugConfig.inboundSwitchboard__),
            address(_plugConfig.outboundSwitchboard__),
            address(_plugConfig.capacitor__),
            address(_plugConfig.decapacitor__)
        );
    }
}
