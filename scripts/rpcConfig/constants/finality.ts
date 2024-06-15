import { ChainSlug } from "../../../src/enums/chainSlug";

import { ChainFinalityInfo, FinalityBucket } from "../../../src/socket-types";

export const finalityOverrides: {
  [chainSlug in ChainSlug]?: ChainFinalityInfo;
} = {
  [ChainSlug.POLYGON_MAINNET]: {
    [FinalityBucket.fast]: 64,
    [FinalityBucket.medium]: 150,
    [FinalityBucket.slow]: 256,
  },
};
