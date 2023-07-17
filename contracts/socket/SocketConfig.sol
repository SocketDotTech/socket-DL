// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../interfaces/ISocket.sol";
import "../interfaces/ICapacitorFactory.sol";
import "../interfaces/ISwitchboard.sol";

/**
 * @title SocketConfig
 * @notice An abstract contract for configuring socket connections for plugs between different chains,
 * manages plug configs and switchboard registrations
 * @dev This contract is meant to be inherited by other contracts that require socket configuration functionality
 */
abstract contract SocketConfig is ISocket {
    // factory contract that can deploy capacitors and decapacitors
    ICapacitorFactory public capacitorFactory__;

    /**
     * @dev Struct to store the configuration for a plug connection
     */
    struct PlugConfig {
        // address of the sibling plug on the remote chain
        address siblingPlug;
        // capacitor instance for the outbound plug connection
        ICapacitor capacitor__;
        // decapacitor instance for the inbound plug connection
        IDecapacitor decapacitor__;
        // inbound switchboard instance for the plug connection
        ISwitchboard inboundSwitchboard__;
        // outbound switchboard instance for the plug connection
        ISwitchboard outboundSwitchboard__;
    }

    // plug => remoteChainSlug => (siblingPlug, capacitor__, decapacitor__, inboundSwitchboard__, outboundSwitchboard__)
    mapping(address => mapping(uint32 => PlugConfig)) internal _plugConfigs;

    // It is used to maintain record of capacitors in the system registered for a slug and also used in seal for verification
    // capacitor address => siblingChainSlug
    mapping(address => uint32) public capacitorToSlug;

    // switchboard => siblingChainSlug => ICapacitor
    mapping(address => mapping(uint32 => ICapacitor)) public capacitors__;

    // switchboard => siblingChainSlug => IDecapacitor
    mapping(address => mapping(uint32 => IDecapacitor)) public decapacitors__;

    // Event triggered when a new switchboard is added
    event SwitchboardAdded(
        address switchboard,
        uint32 siblingChainSlug,
        address capacitor,
        address decapacitor,
        uint256 maxPacketLength,
        uint256 capacitorType
    );

    // Event triggered when a new switchboard is added
    event SiblingSwitchboardUpdated(
        address switchboard,
        uint32 siblingChainSlug,
        address siblingSwitchboard
    );

    // Error triggered when a switchboard already exists
    error SwitchboardExists();
    // Error triggered when a connection is invalid
    error InvalidConnection();

    /**
     * @notice deploy capacitor and decapacitor for a switchboard with a specified max packet length, sibling chain slug, and capacitor type.
     * @param siblingChainSlug_ The slug of the sibling chain that the switchboard is registered with.
     * @param maxPacketLength_ The maximum length of a packet allowed by the switchboard.
     * @param capacitorType_ The type of capacitor that the switchboard uses.
     * @param siblingSwitchboard_ The switchboard address deployed on `siblingChainSlug_`
     */
    function registerSwitchboardForSibling(
        uint32 siblingChainSlug_,
        uint256 maxPacketLength_,
        uint256 capacitorType_,
        address siblingSwitchboard_
    ) external override returns (address capacitor, address decapacitor) {
        address switchboardAddress = msg.sender;
        // only capacitor checked, decapacitor assumed will exist if capacitor does
        if (
            address(capacitors__[switchboardAddress][siblingChainSlug_]) !=
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

        capacitor = address(capacitor__);
        decapacitor = address(decapacitor__);

        capacitorToSlug[capacitor] = siblingChainSlug_;
        capacitors__[switchboardAddress][siblingChainSlug_] = capacitor__;
        decapacitors__[switchboardAddress][siblingChainSlug_] = decapacitor__;

        emit SwitchboardAdded(
            switchboardAddress,
            siblingChainSlug_,
            capacitor,
            decapacitor,
            maxPacketLength_,
            capacitorType_
        );

        emit SiblingSwitchboardUpdated(
            switchboardAddress,
            siblingChainSlug_,
            siblingSwitchboard_
        );
    }

    /**
     * @notice Emits the sibling switchboard for given `siblingChainSlug_`.
     * @dev This function is expected to be only called by switchboard.
     * @dev the event emitted is tracked by transmitters to decide which switchboard a packet should be proposed on
     * @param siblingChainSlug_ The slug of the sibling chain
     * @param siblingSwitchboard_ The switchboard address deployed on `siblingChainSlug_`
     */
    function useSiblingSwitchboard(
        uint32 siblingChainSlug_,
        address siblingSwitchboard_
    ) external {
        emit SiblingSwitchboardUpdated(
            msg.sender,
            siblingChainSlug_,
            siblingSwitchboard_
        );
    }

    /**
     * @notice connects Plug to Socket and sets the config for given `siblingChainSlug_`
     * @notice msg.sender is stored as plug address against given configuration
     * @param siblingChainSlug_ the sibling chain slug
     * @param siblingPlug_ address of plug present at siblingChainSlug_ to call at inbound
     * @param inboundSwitchboard_ the address of switchboard to use for verifying messages at inbound
     * @param outboundSwitchboard_ the address of switchboard to use for sending messages
     */
    function connect(
        uint32 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external override {
        // only capacitor checked, decapacitor assumed will exist if capacitor does
        // as they both are deployed together always
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
            siblingPlug_,
            inboundSwitchboard_,
            outboundSwitchboard_,
            address(_plugConfig.capacitor__),
            address(_plugConfig.decapacitor__)
        );
    }

    /**
     * @notice returns the config for given `plugAddress_` and `siblingChainSlug_`
     * @param siblingChainSlug_ the sibling chain slug
     * @param plugAddress_ address of plug present at current chain
     */
    function getPlugConfig(
        address plugAddress_,
        uint32 siblingChainSlug_
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
