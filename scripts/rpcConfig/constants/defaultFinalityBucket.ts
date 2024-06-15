import { ChainSlug } from "../../../src/enums/chainSlug";

import { FinalityBucket } from "../../../src/socket-types";

export const defaultFinalityBucket = {
  [ChainSlug.POLYGON_MAINNET]: FinalityBucket.slow,
  [ChainSlug.MAINNET]: FinalityBucket.medium,
};
