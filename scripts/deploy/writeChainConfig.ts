import path from "path";
import fs from "fs";
import { writeFile } from "fs/promises";
import { addChainToSDK } from "./single-click-deploy/integrators/writeConfigs";
import { updateConstants } from "../rpcConfig/updateConstants";

const configFilePath = path.join(__dirname, `/../../`);
const configPath = configFilePath + ".env";
const configExamplePath = configFilePath + ".env.example";

const main = async () => {
  try {
    const { response } = await addChainToSDK();
    await updateConstants(response.chainName);

    appendToEnvFile(
      configPath,
      `\n${response.chainName.toUpperCase()}_RPC=${response.rpc}\n`,
      ".env"
    );
    appendToEnvFile(
      configExamplePath,
      `\n${response.chainName.toUpperCase()}_RPC=' '\n`,
      ".env.example"
    );
  } catch (error) {
    console.log("Error:", error);
  }
};

async function appendToEnvFile(path, stringToAppend, fileName) {
  try {
    let configsString = "";
    const outputExists = fs.existsSync(path);
    console.log(path, outputExists);

    if (outputExists) {
      configsString = fs.readFileSync(path, "utf-8");
    }

    configsString = configsString + stringToAppend;
    console.log(configsString);

    fs.writeFileSync(path, configsString);
    console.log("Created env");
  } catch (error) {
    console.log(error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
