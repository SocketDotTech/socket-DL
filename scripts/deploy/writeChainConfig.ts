import path from "path";
import fs from "fs";
import { writeFile } from "fs/promises";
import { addChainToSDK } from "./single-click-deploy/integrators/writeConfigs";

const configFilePath = path.join(__dirname, `/../../`);
const configPath = configFilePath + ".env";
const configExamplePath = configFilePath + ".env.example";

const main = async () => {
    try {
        const { response } = await addChainToSDK();
        appendToEnvFile(configPath, `\n${response.chainName}_RPC=${response.rpc}\n`, ".env");
        appendToEnvFile(configExamplePath, `\n${response.chainName}_RPC=" "\n`, ".env.example");
    } catch (error) {
        console.log("Error:", error);
    }
};

async function appendToEnvFile(path, stringToAppend, fileName) {
    let configsString = "";
    const outputExists = fs.existsSync(path);
    if (outputExists) {
        configsString = fs.readFileSync(configPath, "utf-8");
    }

    configsString = configsString + stringToAppend;
    await writeFile(fileName, configsString);
    console.log("Created env");

}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
