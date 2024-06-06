import path from "path";
import fs from "fs";
import { addChainToSDK } from "./single-click-deploy/integrators/writeConfigs";
import { updateConstants } from "../rpcConfig/updateConstants";

const configFilePath = path.join(__dirname, `/../../`);
const configPath = configFilePath + ".env";
const configExamplePath = configFilePath + ".env.example";

const main = async () => {
  try {
    const { response, isAlreadyAdded } = await addChainToSDK();
    if (!isAlreadyAdded) {
      await updateConstants(response.chainName, response.explorer, response.icon);
    }

    appendToEnvFile(
      configPath,
      `${response.chainName.toUpperCase()}_RPC`,
      `\n${response.chainName.toUpperCase()}_RPC=${response.rpc}\n`,
      ".env"
    );
    appendToEnvFile(
      configExamplePath,
      `${response.chainName.toUpperCase()}_RPC`,
      `\n${response.chainName.toUpperCase()}_RPC=' '\n`,
      ".env.example"
    );
  } catch (error) {
    console.log("Error:", error);
  }
};

async function appendToEnvFile(path, key, stringToAppend, fileName) {
  try {
    let configsString = "";
    const outputExists = fs.existsSync(path);

    if (outputExists) {
      configsString = fs.readFileSync(path, "utf-8");
      const envObject = parseEnvFile(path);
      const keys = Object.keys(envObject).filter((k) => k === key);
      if (keys.length > 0) return;
    }

    configsString = configsString + stringToAppend;

    fs.writeFileSync(path, configsString);
    console.log("Created env");
  } catch (error) {
    console.log(error);
  }
}

export const parseEnvFile = (filePath) => {
  try {
    // Read the file content
    const content = fs.readFileSync(filePath, { encoding: "utf-8" });
    const envObject = {};

    // Split content into lines
    content.split(/\r?\n/).forEach((line) => {
      // Remove leading and trailing whitespaces
      line = line.trim();

      // Ignore empty lines and lines starting with `#` (comments)
      if (line !== "" && !line.startsWith("#")) {
        // Split the line into key and value by the first `=`
        let [key, ...value] = line.split("=");
        key = key.trim();
        let finalValue = value.join("=").trim(); // Join back the value in case it contains `=`
        if (
          (finalValue.startsWith('"') && finalValue.endsWith('"')) ||
          (finalValue.startsWith("'") && finalValue.endsWith("'"))
        ) {
          finalValue = finalValue.substring(1, finalValue.length - 1);
        }
        // Only add to the object if the key is not empty
        if (key) {
          envObject[key] = finalValue;
        }
      }
    });

    return envObject;
  } catch (error) {
    console.error("Failed to read the .env file:", error);
    return {};
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
