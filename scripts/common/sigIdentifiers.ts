import { utils } from "ethers";

export const TRIP_PATH_SIG_IDENTIFIER = utils.id("TRIP_PATH");
export const TRIP_PROPOSAL_SIG_IDENTIFIER = utils.id("TRIP_PROPOSAL");
export const TRIP_GLOBAL_SIG_IDENTIFIER = utils.id("TRIP_GLOBAL");

export const UN_TRIP_PATH_SIG_IDENTIFIER = utils.id("UN_TRIP_PATH");
export const UN_TRIP_GLOBAL_SIG_IDENTIFIER = utils.id("UN_TRIP_GLOBAL");

// native switchboards
export const TRIP_NATIVE_SIG_IDENTIFIER = utils.id("TRIP_NATIVE");
export const UN_TRIP_NATIVE_SIG_IDENTIFIER = utils.id("UN_TRIP_NATIVE");

// value threshold, price and fee updaters
export const FEES_UPDATE_SIG_IDENTIFIER = utils.id("FEES_UPDATE");
export const RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER = utils.id(
  "RELATIVE_NATIVE_TOKEN_PRICE_UPDATE"
);
export const MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER = utils.id(
  "MSG_VALUE_MIN_THRESHOLD_UPDATE"
);
export const MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER = utils.id(
  "MSG_VALUE_MAX_THRESHOLD_UPDATE"
);
