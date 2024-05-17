import { ChainSlug, IntegrationTypes, NativeSwitchboard } from "../../src";
export declare const maxAllowedPacketLength = 10;
export declare const timeout: (chain: number) => number;
export declare const getDefaultIntegrationType: (chain: ChainSlug, sibling: ChainSlug) => IntegrationTypes;
export declare const switchboards: {
    [x: number]: {
        [x: number]: {
            switchboard: NativeSwitchboard;
        };
    };
};
