import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { arrayify } from "@ethersproject/bytes";
import { defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { Contract, Wallet, utils } from "ethers";
import { version } from "../../../src/index";
import { getProviderFromChainName } from "../../constants/networks";

import {
  CORE_CONTRACTS,
  ChainKey,
  getAddresses,
  networkToChainSlug,
} from "@socket.tech/dl-core";
import { getInstance } from "../utils";
import { mode } from "../config";

export const VERSION_HASH = utils.id(version[mode]);

const chain: ChainKey = ChainKey.OPTIMISM_GOERLI;
const packetId =
  "0x000138815c83e326c0b4380127dccf01c3b69ff4dd5c16ae0000000000000001";
const root =
  "0x20b91edb1b25a3ea4403f9296edaff84d689c08b249406fdc6e248ada2919ef7";

export const main = async () => {
  try {
    if (!chain) throw new Error("No chain found!");
    const signer = new Wallet(
      process.env.SOCKET_SIGNER_KEY!,
      getProviderFromChainName(chain)
    );

    if (!process.env.TRANSMITTER_PK)
      throw new Error("No transmitter PK found!");

    const transmitterSigner = new Wallet(
      process.env.TRANSMITTER_PK!,
      getProviderFromChainName(chain)
    );

    const proposeDigest = keccak256(
      defaultAbiCoder.encode(
        ["bytes32", "uint32", "bytes32", "bytes32"],
        [VERSION_HASH, networkToChainSlug[chain], packetId, root]
      )
    );
    const signature = await transmitterSigner.signMessage(
      arrayify(proposeDigest)
    );

    console.log(`${signature} here`);

    const socket: Contract = (
      await getInstance(
        CORE_CONTRACTS.Socket,
        (
          await getAddresses(networkToChainSlug[chain], mode)
        ).Socket
      )
    ).connect(signer);

    const tx = await socket.propose(packetId, root, signature);

    console.log(`Proposing at tx hash: ${tx.hash}`);
    await tx.wait();
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
