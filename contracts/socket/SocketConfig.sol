// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISocket.sol";
import "../interfaces/ICapacitorFactory.sol";
import "../interfaces/ISwitchboard.sol";
import "../utils/AccessControlExtended.sol";
import {GOVERNANCE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title SocketConfig
 * @notice An abstract contract for configuring socket connections between different chains
 * @dev This contract is meant to be inherited by other contracts that require socket configuration functionality
 */
abstract contract SocketConfig is ISocket, AccessControlExtended {
    /**
     * @dev Struct to hold the configuration for a plug connection
     */
    struct PlugConfig {
        // address of the sibling plug on the remote chain
        address siblingPlug;
        // capacitor instance for the plug connection
        ICapacitor capacitor__;
        // decapacitor instance for the plug connection
        IDecapacitor decapacitor__;
        // inbound switchboard instance for the plug connection
        ISwitchboard inboundSwitchboard__;
        // outbound switchboard instance for the plug connection
        ISwitchboard outboundSwitchboard__;
    }

    // Capacitor factory contract
    ICapacitorFactory public capacitorFactory__;

    // siblingChainSlug => capacitor address
    mapping(address => uint32) public capacitorToSlug;

    // switchboard => siblingChainSlug => ICapacitor
    mapping(address => mapping(uint256 => ICapacitor)) public capacitors__;
    // switchboard => siblingChainSlug => IDecapacitor
    mapping(address => mapping(uint256 => IDecapacitor)) public decapacitors__;

    // plug => remoteChainSlug => (siblingPlug, capacitor__, decapacitor__, inboundSwitchboard__, outboundSwitchboard__)
    mapping(address => mapping(uint256 => PlugConfig)) internal _plugConfigs;

    // Event triggered when a new switchboard is added
    event SwitchboardAdded(
        address switchboard,
        uint256 siblingChainSlug,
        address capacitor,
        address decapacitor,
        uint256 maxPacketLength,
        uint32 capacitorType
    );
    // Event triggered when the capacitor factory is set
    event CapacitorFactorySet(address capacitorFactory);

    // Error triggered when a switchboard already exists
    error SwitchboardExists();
    // Error triggered when a connection is invalid
    error InvalidConnection();

    /**
     * @dev Set the capacitor factory contract
     * @param capacitorFactory_ The address of the capacitor factory contract
     */
    function setCapacitorFactory(
        address capacitorFactory_
    ) external onlyRole(GOVERNANCE_ROLE) {
        capacitorFactory__ = ICapacitorFactory(capacitorFactory_);
        emit CapacitorFactorySet(capacitorFactory_);
    }

    /**
     * @dev Register a switchboard with the given configuration
     * @dev It's msg.sender's responsibility to set correct sibling slug
     * @param switchBoardAddress_ The address of the switchboard to register
     * @param maxPacketLength_ The maximum packet length supported by the switchboard
     * @param siblingChainSlug_ The sibling chain slug to register the switchboard with
     * @param capacitorType_ The type of capacitor to use for the switchboard
     */
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

    /**
     * @notice sets the config specific to the plug
     * @param siblingChainSlug_ the sibling chain slug
     * @param siblingPlug_ address of plug present at sibling chain to call inbound
     * @param inboundSwitchboard_ the address of switchboard to use for receiving messages
     * @param outboundSwitchboard_ the address of switchboard to use for sending messages
     */
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

    /**
     * @notice returns the config for given plug and sibling
     * @param siblingChainSlug_ the sibling chain slug
     * @param plugAddress_ address of plug present at current chain
     */
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
