// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISocket.sol";
import "../interfaces/ICapacitorFactory.sol";
import "../interfaces/ISwitchboard.sol";
import "../utils/AccessControlExtended.sol";
import {GOVERNANCE_ROLE} from "../utils/AccessRoles.sol";

abstract contract SocketConfig is ISocket, AccessControlExtended {
    struct PlugConfig {
        address siblingPlug;
        ICapacitor capacitor__;
        IDecapacitor decapacitor__;
        ISwitchboard inboundSwitchboard__;
        ISwitchboard outboundSwitchboard__;
    }

    ICapacitorFactory public capacitorFactory__;

    // siblingChainSlug => capacitor address
    mapping(address => uint32) public capacitorToSlug;

    // switchboard => siblingChainSlug => ICapacitor
    mapping(address => mapping(uint256 => ICapacitor)) public capacitors__;
    // switchboard => siblingChainSlug => IDecapacitor
    mapping(address => mapping(uint256 => IDecapacitor)) public decapacitors__;

    // plug => remoteChainSlug => (siblingPlug, capacitor__, decapacitor__, inboundSwitchboard__, outboundSwitchboard__)
    mapping(address => mapping(uint256 => PlugConfig)) internal _plugConfigs;

    event SwitchboardAdded(
        address switchboard,
        uint256 siblingChainSlug,
        address capacitor,
        address decapacitor,
        uint256 maxPacketLength,
        uint32 capacitorType
    );
    event CapacitorFactorySet(address capacitorFactory);

    error SwitchboardExists();
    error InvalidConnection();

    function setCapacitorFactory(
        address capacitorFactory_
    ) external onlyRole(GOVERNANCE_ROLE) {
        capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
        emit CapacitorFactorySet(capacitorFactory_);
    }

    // it's msg.sender's responsibility to set correct sibling slug
    function registerSwitchBoard(
        address switchBoardAddress_,
        uint256 maxPacketLength_,
        uint32 siblingChainSlug_,
        uint32 capacitorType_
    ) external override {
        // only capacitor checked, decapacitor assumed will exist if capacitor does
        if (
            address(capacitors__[switchBoardAddress_][siblingChainSlug_]) !=
            address(0)
        ) revert SwitchboardExists();

        (
            ICapacitor capacitor__,
            IDecapacitor decapacitor__
        ) = capacitorFactory__.deploy(
                capacitorType_,
                siblingChainSlug_,
                maxPacketLength_
            );

        capacitorToSlug[address(capacitor__)] = siblingChainSlug_;
        capacitors__[switchBoardAddress_][siblingChainSlug_] = capacitor__;
        decapacitors__[switchBoardAddress_][siblingChainSlug_] = decapacitor__;

        ISwitchboard(switchBoardAddress_).registerCapacitor(
            siblingChainSlug_,
            address(capacitor__),
            maxPacketLength_
        );

        emit SwitchboardAdded(
            switchBoardAddress_,
            siblingChainSlug_,
            address(capacitor__),
            address(decapacitor__),
            maxPacketLength_,
            capacitorType_
        );
    }

    function connect(
        uint256 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external override {
        if (
            address(capacitors__[inboundSwitchboard_][siblingChainSlug_]) ==
            address(0) ||
            address(capacitors__[outboundSwitchboard_][siblingChainSlug_]) ==
            address(0)
        ) revert InvalidConnection();

        PlugConfig storage _plugConfig = _plugConfigs[msg.sender][
            siblingChainSlug_
        ];

        _plugConfig.siblingPlug = siblingPlug_;
        _plugConfig.capacitor__ = capacitors__[outboundSwitchboard_][
            siblingChainSlug_
        ];
        _plugConfig.decapacitor__ = decapacitors__[inboundSwitchboard_][
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

    function getPlugConfig(
        address plugAddress_,
        uint256 siblingChainSlug_
    )
        external
        view
        returns (
            address siblingPlug,
            address inboundSwitchboard__,
            address outboundSwitchboard__,
            address capacitor__,
            address decapacitor__
        )
    {
        PlugConfig memory _plugConfig = _plugConfigs[plugAddress_][
            siblingChainSlug_
        ];

        return (
            _plugConfig.siblingPlug,
            address(_plugConfig.inboundSwitchboard__),
            address(_plugConfig.outboundSwitchboard__),
            address(_plugConfig.capacitor__),
            address(_plugConfig.decapacitor__)
        );
    }
}
