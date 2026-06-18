import { execFileSync } from "child_process";
import fs from "fs";

type AddressBook = {
  [chainSlug: string]: {
    SafeL2?: string;
    SafeProxyFactory?: string;
    SocketSafeProxy?: string;
  };
};

type BuildInfo = {
  solcLongVersion: string;
  input: {
    language: string;
    sources: Record<string, unknown>;
    settings: Record<string, unknown>;
  };
  output: {
    contracts: Record<string, Record<string, unknown>>;
  };
};

type ExplorerConfig = {
  apiUrl: string;
  apiKeyEnv?: string;
  includeChainId?: boolean;
  resolveHostIp?: string;
  insecure?: boolean;
};

type ContractTarget = {
  name: string;
  address: string;
  contractPath: string;
  contractName: string;
  constructorArguments: string;
};

type ChainResult = {
  chain: string;
  apiUrl: string;
  addresses: {
    SafeL2: string;
    SafeProxyFactory: string;
    SocketSafeProxy: string;
  };
  source: Record<string, string>;
  proxy: string;
  errors: string[];
};

const ETHERSCAN_V2 = "https://api.etherscan.io/v2/api";
const REPORT_PATH =
  process.env.REPORT_PATH || "/tmp/socket_dl_all_safe_verification_report.json";

const EXPLORERS: Record<string, ExplorerConfig> = {
  "1": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "10": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "14": { apiUrl: "https://flare-explorer.flare.network/api" },
  "56": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "100": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "130": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "137": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "143": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "146": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "169": { apiUrl: "https://pacific-explorer.manta.network/api" },
  "196": { apiUrl: "https://www.okx.com/web3/explorer/xlayer/api" },
  "204": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "404": { apiUrl: "https://explorer.syndr.com/api" },
  "480": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "901": { apiUrl: "https://testnet-explorer.lyra.finance/api" },
  "957": { apiUrl: "https://explorer.lyra.finance/api" },
  "999": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "1101": {
    apiUrl: "https://api-zkevm.polygonscan.com/api",
    apiKeyEnv: "ZKEVM_API_KEY",
  },
  "1329": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "1868": { apiUrl: "https://soneium.blockscout.com/api" },
  "1923": { apiUrl: "https://explorer.swellnetwork.io/api" },
  "2999": { apiUrl: "https://explorer.aevo.xyz/api" },
  "4153": { apiUrl: "https://explorer.risechain.com/api" },
  "4326": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "5000": { apiUrl: "https://explorer.mantle.xyz/api" },
  "7897": { apiUrl: "https://explorer.arena-z.gg/api", insecure: true },
  "8008": { apiUrl: "https://explorer.polynomial.fi/api" },
  "8453": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "9745": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "10143": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "34443": { apiUrl: "https://explorer.mode.network/api" },
  "42161": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "43114": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "47763": { apiUrl: "https://xexplorer.neo.org/api" },
  "57073": { apiUrl: "https://explorer.inkonchain.com/api" },
  "59144": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "63157": { apiUrl: "https://geist-mainnet.explorer.alchemy.com/api" },
  "80094": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "81457": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "98866": { apiUrl: "https://explorer.plume.org/api" },
  "421614": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "534352": {
    apiUrl: "https://api.scrollscan.com/api",
    apiKeyEnv: "SCROLLSCAN_API_KEY",
  },
  "747474": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "5064014": { apiUrl: "https://explorer.ethereal.trade/api" },
  "11155111": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "11155112": { apiUrl: "https://explorer-testnet.aevo.xyz/api" },
  "11155420": {
    apiUrl: ETHERSCAN_V2,
    apiKeyEnv: "ETHERSCAN_API_KEY",
    includeChainId: true,
    resolveHostIp: "23.92.68.154",
  },
  "89346162": { apiUrl: "https://reya-cronos.blockscout.com/api" },
  "1324967486": { apiUrl: "https://explorer.reya.network/api" },
};

function getEnv(name: string): string | undefined {
  const env = fs.existsSync(".env") ? fs.readFileSync(".env", "utf8") : "";
  const line = env
    .split("\n")
    .find((entry) => entry.trim().startsWith(`${name}=`));
  return line
    ?.split("=")
    .slice(1)
    .join("=")
    .trim()
    .replace(/^['"]|['"]$/g, "");
}

function sanitizeError(message: string): string {
  let sanitized = message.replace(
    /apikey=[^&\s'"]+/gi,
    "apikey=***redacted***"
  );
  for (const config of Object.values(EXPLORERS)) {
    if (!config.apiKeyEnv) continue;
    const key = getEnv(config.apiKeyEnv);
    if (key) sanitized = sanitized.split(key).join("***redacted***");
  }
  return sanitized;
}

function findBuildInfo(contractPath: string, contractName: string): BuildInfo {
  for (const file of fs.readdirSync("artifacts/build-info")) {
    const buildInfo = JSON.parse(
      fs.readFileSync(`artifacts/build-info/${file}`, "utf8")
    ) as BuildInfo;

    if (buildInfo.output.contracts[contractPath]?.[contractName]) {
      return buildInfo;
    }
  }

  throw new Error(`Build info not found for ${contractPath}:${contractName}`);
}

function encodeAddressConstructorArg(address: string): string {
  return address.toLowerCase().replace(/^0x/, "").padStart(64, "0");
}

function baseCurlArgs(config: ExplorerConfig): string[] {
  const args: string[] = ["-L"];
  if (config.insecure) args.push("-k");
  if (config.resolveHostIp) {
    const host = new URL(config.apiUrl).host;
    args.push("--resolve", `${host}:443:${config.resolveHostIp}`);
  }
  args.push("-sS");
  return args;
}

function withCommonFields(
  config: ExplorerConfig,
  chain: string,
  apiKey: string | undefined,
  fields: Record<string, string>
): Record<string, string> {
  return {
    ...(apiKey ? { apikey: apiKey } : {}),
    ...(config.includeChainId ? { chainid: chain } : {}),
    ...fields,
  };
}

function curlGet(
  config: ExplorerConfig,
  query: Record<string, string>
): string {
  const params = new URLSearchParams(query).toString();
  return execFileSync(
    "curl",
    [...baseCurlArgs(config), `${config.apiUrl}?${params}`],
    {
      encoding: "utf8",
      maxBuffer: 4 * 1024 * 1024,
    }
  );
}

function curlPost(
  config: ExplorerConfig,
  fields: Record<string, string>
): string {
  const postFields = { ...fields };
  let apiUrl = config.apiUrl;
  if (config.includeChainId && postFields.chainid) {
    apiUrl = `${apiUrl}?${new URLSearchParams({
      chainid: postFields.chainid,
    })}`;
    delete postFields.chainid;
  }

  const args = [...baseCurlArgs(config), "-X", "POST", apiUrl];
  for (const [key, value] of Object.entries(postFields)) {
    args.push("--data-urlencode", `${key}=${value}`);
  }

  return execFileSync("curl", args, {
    encoding: "utf8",
    maxBuffer: 30 * 1024 * 1024,
  });
}

function parseJson(output: string) {
  try {
    return JSON.parse(output);
  } catch {
    throw new Error(
      `Explorer returned non-JSON response: ${output.slice(0, 120)}`
    );
  }
}

function writeReport(results: ChainResult[]) {
  fs.writeFileSync(
    REPORT_PATH,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        chains: results,
      },
      null,
      2
    )
  );
}

async function sleep(ms: number) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

function isAlreadyVerifiedMessage(value: string): boolean {
  return (
    /already verified/i.test(value) ||
    /source code already verified/i.test(value)
  );
}

async function ensureSourceVerified(
  config: ExplorerConfig,
  apiKey: string | undefined,
  chain: string,
  target: ContractTarget
): Promise<string> {
  const sourceStatus = parseJson(
    curlGet(
      config,
      withCommonFields(config, chain, apiKey, {
        module: "contract",
        action: "getsourcecode",
        address: target.address,
      })
    )
  );

  const sourceResult = Array.isArray(sourceStatus.result)
    ? sourceStatus.result[0]
    : sourceStatus.result;
  if (
    sourceStatus.status === "1" &&
    sourceResult &&
    typeof sourceResult === "object" &&
    sourceResult.SourceCode
  ) {
    return "already verified";
  }

  const buildInfo = findBuildInfo(target.contractPath, target.contractName);
  const response = parseJson(
    curlPost(
      config,
      withCommonFields(config, chain, apiKey, {
        module: "contract",
        action: "verifysourcecode",
        contractaddress: target.address,
        sourceCode: JSON.stringify(buildInfo.input),
        codeformat: "solidity-standard-json-input",
        contractname: `${target.contractPath}:${target.contractName}`,
        compilerversion: `v${buildInfo.solcLongVersion}`,
        optimizationUsed: "1",
        runs: "999999",
        constructorArguements: target.constructorArguments,
        evmversion: "paris",
        licenseType: "6",
      })
    )
  );

  if (response.status !== "1") {
    const result = String(response.result || "");
    if (isAlreadyVerifiedMessage(result)) return "already verified";
    throw new Error(`submit failed: ${JSON.stringify(response)}`);
  }

  const guid = String(response.result);
  for (let attempt = 1; attempt <= 30; attempt++) {
    await sleep(5000);
    const status = parseJson(
      curlGet(
        config,
        withCommonFields(config, chain, apiKey, {
          module: "contract",
          action: "checkverifystatus",
          guid,
        })
      )
    );

    if (status.status === "1") return String(status.result || "verified");
    const result = String(status.result || "");
    if (isAlreadyVerifiedMessage(result)) return "already verified";
    if (!/pending/i.test(result)) {
      throw new Error(`verification failed: ${JSON.stringify(status)}`);
    }
  }

  throw new Error("verification still pending after polling limit");
}

async function verifyProxyLink(
  config: ExplorerConfig,
  apiKey: string | undefined,
  chain: string,
  proxy: string,
  implementation: string
): Promise<string> {
  const response = parseJson(
    curlPost(
      config,
      withCommonFields(config, chain, apiKey, {
        module: "contract",
        action: "verifyproxycontract",
        address: proxy,
        expectedimplementation: implementation,
      })
    )
  );

  if (response.status !== "1") {
    const result = String(response.result || "");
    if (isAlreadyVerifiedMessage(result)) return "already linked";
    throw new Error(`proxy submit failed: ${JSON.stringify(response)}`);
  }

  const guid = String(response.result);
  for (let attempt = 1; attempt <= 20; attempt++) {
    await sleep(5000);
    const status = parseJson(
      curlGet(
        config,
        withCommonFields(config, chain, apiKey, {
          module: "contract",
          action: "checkproxyverification",
          guid,
        })
      )
    );

    if (status.status === "1") return String(status.result || "proxy linked");
    const result = String(status.result || "");
    if (isAlreadyVerifiedMessage(result)) return "already linked";
    if (!/pending/i.test(result)) {
      throw new Error(`proxy verification failed: ${JSON.stringify(status)}`);
    }
  }

  throw new Error("proxy verification still pending after polling limit");
}

async function main() {
  const addresses = JSON.parse(
    fs.readFileSync("deployments/prod_addresses.json", "utf8")
  ) as AddressBook;
  const requestedChains = (
    process.env.CHAIN_SLUGS || Object.keys(addresses).join(",")
  )
    .split(",")
    .map((chain) => chain.trim())
    .filter(Boolean);

  const results: ChainResult[] = [];
  for (const chain of requestedChains) {
    const chainAddresses = addresses[chain];
    const config = EXPLORERS[chain];
    if (!config) continue;

    const apiKey = config.apiKeyEnv ? getEnv(config.apiKeyEnv) : undefined;
    const result: ChainResult = {
      chain,
      apiUrl: config.apiUrl,
      addresses: {
        SafeL2: chainAddresses?.SafeL2 || "",
        SafeProxyFactory: chainAddresses?.SafeProxyFactory || "",
        SocketSafeProxy: chainAddresses?.SocketSafeProxy || "",
      },
      source: {},
      proxy: "not attempted",
      errors: [],
    };
    results.push(result);

    if (
      !chainAddresses?.SafeL2 ||
      !chainAddresses.SafeProxyFactory ||
      !chainAddresses.SocketSafeProxy
    ) {
      result.proxy = "skipped: missing SafeL2/SafeProxyFactory/SocketSafeProxy";
      writeReport(results);
      continue;
    }

    if (config.apiKeyEnv && !apiKey) {
      result.proxy = `skipped: missing ${config.apiKeyEnv}`;
      result.errors.push(`missing ${config.apiKeyEnv}`);
      writeReport(results);
      continue;
    }

    const targets: ContractTarget[] = [
      {
        name: "SafeL2",
        address: chainAddresses.SafeL2,
        contractPath: "contracts/utils/multisig/SafeL2.sol",
        contractName: "SafeL2",
        constructorArguments: "",
      },
      {
        name: "SafeProxyFactory",
        address: chainAddresses.SafeProxyFactory,
        contractPath: "contracts/utils/multisig/proxies/SafeProxyFactory.sol",
        contractName: "SafeProxyFactory",
        constructorArguments: "",
      },
      {
        name: "SocketSafeProxy",
        address: chainAddresses.SocketSafeProxy,
        contractPath: "contracts/utils/multisig/proxies/SafeProxy.sol",
        contractName: "SafeProxy",
        constructorArguments: encodeAddressConstructorArg(
          chainAddresses.SafeL2
        ),
      },
    ];

    console.log(`\nChain ${chain} (${config.apiUrl})`);
    for (const target of targets) {
      try {
        console.log(`  source ${target.name}: ${target.address}`);
        result.source[target.name] = await ensureSourceVerified(
          config,
          apiKey,
          chain,
          target
        );
      } catch (error) {
        const message = sanitizeError(
          error instanceof Error ? error.message : String(error)
        );
        result.source[target.name] = "failed";
        result.errors.push(`${target.name}: ${message}`);
        console.log(`  failed ${target.name}: ${message}`);
      }
      writeReport(results);
      await sleep(1000);
    }

    if (Object.values(result.source).every((status) => status !== "failed")) {
      try {
        console.log(
          `  proxy SocketSafeProxy -> SafeL2: ${chainAddresses.SocketSafeProxy} -> ${chainAddresses.SafeL2}`
        );
        result.proxy = await verifyProxyLink(
          config,
          apiKey,
          chain,
          chainAddresses.SocketSafeProxy,
          chainAddresses.SafeL2
        );
      } catch (error) {
        const message = sanitizeError(
          error instanceof Error ? error.message : String(error)
        );
        result.proxy = "failed";
        result.errors.push(`proxy: ${message}`);
        console.log(`  failed proxy: ${message}`);
      }
    } else {
      result.proxy = "skipped: source verification failed";
    }

    writeReport(results);
    await sleep(2000);
  }

  const summary = results.reduce(
    (acc, result) => {
      if (result.errors.length === 0 && !result.proxy.startsWith("skipped")) {
        acc.ok += 1;
      } else {
        acc.failed += 1;
      }
      return acc;
    },
    { ok: 0, failed: 0 }
  );
  console.log(`\nReport written to ${REPORT_PATH}`);
  console.log(JSON.stringify(summary));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
