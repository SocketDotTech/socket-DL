import path from "path";
import fs from "fs";
import { ChainSlug } from "../../../../src";
import { ChainConfig, ChainConfigs } from "../../../constants";

const configFilePath = path.join(__dirname, `/../../../`);

export const updateConfig = async (
  chainSlug: ChainSlug,
  chainConfig: ChainConfig
) => {
  const addressesPath = configFilePath + "chainConfig.json";
  const outputExists = fs.existsSync(addressesPath);
  let configs: ChainConfigs = {};

  if (outputExists) {
    const configsString = fs.readFileSync(addressesPath, "utf-8");
    configs = JSON.parse(configsString);
  }

  configs[chainSlug] = chainConfig;
  fs.writeFileSync(addressesPath, JSON.stringify(configs, null, 2) + "\n");
};
