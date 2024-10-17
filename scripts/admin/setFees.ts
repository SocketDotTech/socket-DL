import { Contract, Wallet, utils } from "ethers";
import { StaticJsonRpcProvider } from "@ethersproject/providers";
import {
  IntegrationTypes,
  ChainSlug,
  getSwitchboardAddress,
  DeploymentMode,
  CORE_CONTRACTS,
} from "../../src";
import { mode, overrides } from "../deploy/config/config";
import { getProviderFromChainSlug } from "../constants";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { getInstance } from "../deploy/utils";

const chain = ChainSlug.OPTIMISM_GOERLI;
const siblingChain = ChainSlug.ARBITRUM_GOERLI;
const integrationType = IntegrationTypes.fast;
const switchboardFees = "1000000000000000";
const verificationOverheadFees = "1000000000000000";

// before running the script check all the constants above
const main = async () => {
  const switchboard = await getSwitchboardInstance(
    chain,
    siblingChain,
    integrationType,
    mode
  );
  if (switchboard === undefined) return;

  console.log(
    "Setting fees",
    switchboard.address,
    chain,
    siblingChain,
    integrationType,
    switchboardFees,
    verificationOverheadFees
  );

  const nonce = await switchboard.nextNonce(switchboard.signer.getAddress(), {
    ...(await overrides(chain)),
  });
  const digest = keccak256(
    defaultAbiCoder.encode(
      [
        "bytes32",
        "address",
        "uint32",
        "uint32",
        "uint256",
        "uint128",
        "uint128",
      ],
      [
        utils.id("FEES_UPDATE"),
        switchboard.address,
        chain,
        siblingChain,
        nonce,
        switchboardFees,
        verificationOverheadFees,
      ]
    )
  );

  const signature = await switchboard.signer.signMessage(arrayify(digest));

  const tx = await switchboard.setFees(
    nonce,
    siblingChain,
    switchboardFees,
    verificationOverheadFees,
    signature,
    { ...(await overrides(chain)) }
  );
  console.log(tx.hash);

  await tx.wait();
  console.log("done");
};

const sbContracts: { [key: string]: Contract } = {};
const getSwitchboardInstance = async (
  chain: ChainSlug,
  siblingChain: ChainSlug,
  integrationType: IntegrationTypes,
  mode: DeploymentMode
): Promise<Contract | undefined> => {
  let switchboardAddress: string;
  try {
    switchboardAddress = getSwitchboardAddress(
      chain,
      siblingChain,
      integrationType,
      mode
    );
  } catch (e) {
    // means no switchboard found for given params
    return;
  }
  if (!sbContracts[`${chain}${siblingChain}${switchboardAddress}`]) {
    const provider: StaticJsonRpcProvider = getProviderFromChainSlug(chain);
    if (!process.env.SOCKET_SIGNER_KEY)
      throw new Error("SOCKET_SIGNER_KEY not set");
    const signer: Wallet = new Wallet(process.env.SOCKET_SIGNER_KEY, provider);

    sbContracts[`${chain}${siblingChain}${switchboardAddress}`] = (
      await getInstance(CORE_CONTRACTS.FastSwitchboard, switchboardAddress)
    ).connect(signer);
  }
  return sbContracts[`${chain}${siblingChain}${switchboardAddress}`];
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
