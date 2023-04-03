import { ChainId } from "./relayer.config";

export interface RelayerConfig {
  chainId: ChainId;
  rpc: string;
  ozRelayerKey: string;
  ozRelayerSecret: string;
}
