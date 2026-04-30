import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { getProviderFromChainSlug } from "../constants";
import { ChainSlug, ROLES, getAllAddresses } from "../../src";
import { mode } from "../deploy/config/config";
import { getRoleHash } from "../deploy/utils";
import {
  FastSwitchboard__factory,
  Socket__factory,
} from "../../typechain-types";

dotenvConfig();

// --- inputs ---
const PACKET_ID =
  "0x000000015a1576356c264ad1fcdd1d014e207c74858dafc400000000000037f3";
const PROPOSAL_COUNT = 0;
const SIGNATURE =
  "0x226a3a9fe7a2a1b5f94a4ecb3025c813456174398d072c260c2ca5ffe63b03b76dfaf30cfbf62a402336b454673e6b3722b5d8e992f73208c10274813290c2c21c";
const DIGEST =
  "0xfb21b9711377b9c886ea2c957f82b18d401e1b9670b74708ac455fc354ae1034";
const EXPECTED_SIGNER = "0xc86823Db0d64fe7e8bE6262eed408B433AB78d94";
// destination chain where attest() will be called (switchboard lives here)
const DST_CHAIN: ChainSlug = Number(process.env.npm_config_dst) as ChainSlug;

const main = async () => {
  const srcChainSlug = Number(
    ethers.BigNumber.from("0x" + PACKET_ID.slice(2, 10))
  ) as ChainSlug;
  console.log("srcChainSlug:", srcChainSlug);

  // 1) signer recovery (from digest directly)
  const recovered = ethers.utils.recoverAddress(DIGEST, SIGNATURE);
  const sigOk =
    recovered.toLowerCase() === EXPECTED_SIGNER.toLowerCase();
  console.log(`recovered: ${recovered}  match=${sigOk}`);
  if (!sigOk) return;

  if (!DST_CHAIN) {
    console.log("pass --dst=<dstChainSlug> to run on-chain checks");
    return;
  }

  const addresses = getAllAddresses(mode)[DST_CHAIN];
  if (!addresses?.FastSwitchboard || !addresses?.Socket) {
    throw new Error(`missing deployments on dst ${DST_CHAIN}`);
  }

  const provider = getProviderFromChainSlug(DST_CHAIN);
  const sb = FastSwitchboard__factory.connect(
    addresses.FastSwitchboard,
    provider
  );
  const socket = Socket__factory.connect(addresses.Socket, provider);

  // 2) reconstruct digest to confirm switchboard/chainSlug match
  const root = await socket.packetIdRoots(
    PACKET_ID,
    PROPOSAL_COUNT,
    sb.address
  );
  console.log("packetIdRoot on socket:", root);
  if (root === ethers.constants.HashZero) {
    console.log("✗ no root proposed yet — attest would revert InvalidRoot");
    return;
  }

  const rebuilt = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address", "uint32", "bytes32", "uint256", "bytes32"],
      [sb.address, DST_CHAIN, PACKET_ID, PROPOSAL_COUNT, root]
    )
  );
  console.log(`digest rebuilt: ${rebuilt}  match=${rebuilt === DIGEST}`);
  if (rebuilt !== DIGEST) {
    console.log("✗ digest mismatch — sig was made for a different sb/chain/root");
    return;
  }

  // 3) watcher role
  const hasRole = await sb.hasRoleWithSlug(
    getRoleHash(ROLES.WATCHER_ROLE),
    srcChainSlug,
    recovered
  );
  console.log(`has WATCHER_ROLE for src ${srcChainSlug}: ${hasRole}`);

  // 4) already attested
  const already = await sb.isAttested(recovered, root);
  console.log(`already attested: ${already}`);

  const wouldWork = hasRole && !already;
  console.log(wouldWork ? "✅ attest should succeed" : "❌ attest would revert");
};

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
