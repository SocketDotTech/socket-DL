import path from "path";
import fs from "fs";
import dotenv from "dotenv";
dotenv.config();

import { ChainId, DeploymentMode } from "../../src";
import { version, rpcs } from "./constants";

const constantFolderPath = path.join(__dirname, `/constants/`);
export const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;

export const updateConstants = async (chainName: string) => {
  if (!fs.existsSync(constantFolderPath)) {
    throw new Error(`Folder not found! ${constantFolderPath}`);
  }

  const filteredChain = Object.keys(rpcs).filter(
    (c) => c == ChainId[chainName]
  );
  if (filteredChain.length > 0) {
    console.log("Chain already added!");
    return;
  }

  await updateFile(
    "rpc.ts",
    `,\n    [ChainSlug.${chainName.toUpperCase()}]: checkEnvVar("${chainName.toUpperCase()}_RPC"),\n};`,
    ",\n};"
  );
  await updateFile(
    "confirmations.ts",
    `,\n    [ChainSlug.${chainName.toUpperCase()}]: 1,\n};`,
    ",\n};"
  );
  await updateFile(
    "batcherSupportedChainSlug.ts",
    `,\n    ChainSlug.${chainName.toUpperCase()},\n];`,
    ",\n];"
  );

  await updateVersion();
};

const updateFile = async (fileName, newChainDetails, replaceWith) => {
  try {
    const filePath = constantFolderPath + fileName;
    const outputExists = fs.existsSync(filePath);
    if (!outputExists)
      throw new Error(`${fileName} enum not found! ${filePath}`);

    const fileContent = fs.readFileSync(filePath, "utf-8");

    // replace last bracket with new line
    const newFileContent = fileContent
      .trimEnd()
      .replace(replaceWith, newChainDetails);

    fs.writeFileSync(filePath, newFileContent);
  } catch (error) {
    console.log(error);
  }
};

const updateVersion = () => {
  let serializedContent;
  const currentVersion = version[deploymentMode];
  const versions = currentVersion.split(".");
  const newVersion = `${versions[0]}.${versions[1]}.${++versions[2]}`;
  if (deploymentMode === DeploymentMode.PROD) {
    serializedContent = `    [DeploymentMode.DEV]: "${
      version[DeploymentMode.DEV]
    }",
    [DeploymentMode.PROD]: "${newVersion}",`;
  } else if (deploymentMode === DeploymentMode.DEV) {
    serializedContent = `    [DeploymentMode.DEV]: "${newVersion}",
    [DeploymentMode.PROD]: "${version[DeploymentMode.PROD]}",`;
  }

  const content = `import { DeploymentMode } from "../../../src";

export const version = {
${serializedContent}
};`;

  fs.writeFileSync(constantFolderPath + "version.ts", content);
};
