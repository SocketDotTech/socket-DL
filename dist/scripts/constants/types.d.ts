import { ChainSlug } from "../../src";
export type RoleOwners = {
    ownerAddress: string;
    executorAddress: string;
    transmitterAddress: string;
    watcherAddress: string;
    feeUpdaterAddress: string;
};
export type ChainConfig = {
    roleOwners: RoleOwners;
    siblings: ChainSlug[];
    timeout?: number;
    msgValueMaxThreshold?: string;
    overrides?: {
        type?: number;
        gasLimit?: string;
        gasPrice?: string;
    };
};
export type ChainConfigs = {
    [chainSlug in ChainSlug]?: ChainConfig;
};
