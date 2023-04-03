import { ChainId } from "./relayer.config";

export type Speed = "safeLow" | "average" | "fast" | "fastest";

export const relayTxSpeed: Speed =
  (process.env.RELAY_TX_SPEED as Speed) || "fast";

export interface RelayerConfig {
  chainId: ChainId;
  rpc: string;
  ozRelayerKey: string;
  ozRelayerSecret: string;
}
