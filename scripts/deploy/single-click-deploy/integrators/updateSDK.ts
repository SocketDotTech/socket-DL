import path from "path";
import fs from "fs";
import { ChainId } from "../../../../src";

const enumFolderPath = path.join(__dirname, `/../../../../src/enums/`);

export const updateSDK = async (
  chainName: string,
  chainId: number,
  isMainnet: boolean
) => {
  if (!fs.existsSync(enumFolderPath)) {
    throw new Error(`Folder not found! ${enumFolderPath}`);
  }

  const filteredChain = Object.values(ChainId).filter((c) => c == chainId);
  if (filteredChain.length > 0) {
    console.log("Chain already added!");
    return;
  }

  await updateFile(
    "hardhatChainName.ts",
    `,\n  ${chainName.toUpperCase()} = "${chainName.toLowerCase()}",\n}\n`,
    ",\n}"
  );
  await updateFile(
    "chainId.ts",
    `,\n  ${chainName.toUpperCase()} = ${chainId},\n}\n`,
    ",\n}"
  );
  await updateFile(
    "chainSlug.ts",
    `,\n  ${chainName.toUpperCase()} = ChainId.${chainName.toUpperCase()},\n}\n`,
    ",\n}"
  );
  await updateFile(
    "chainSlugToKey.ts",
    `,\n  [ChainSlug.${chainName.toUpperCase()}]: HardhatChainName.${chainName.toUpperCase()},\n}\n`,
    ",\n}"
  );
  await updateFile(
    "chainSlugToId.ts",
    `,\n  [ChainSlug.${chainName.toUpperCase()}]: ChainId.${chainName.toUpperCase()},\n}\n`,
    ",\n}"
  );
  await updateFile(
    "hardhatChainNameToSlug.ts",
    `,\n  [HardhatChainName.${chainName.toUpperCase()}]: ChainSlug.${chainName.toUpperCase()},\n}\n`,
    ",\n}"
  );

  if (isMainnet) {
    await updateFile(
      "mainnetIds.ts",
      `,\n  ChainSlug.${chainName.toUpperCase()},\n];\n`,
      ",\n];"
    );
  } else
    await updateFile(
      "testnetIds.ts",
      `,\n  ChainSlug.${chainName.toUpperCase()},\n];\n`,
      ",\n];"
    );
};

const updateFile = async (fileName, newChainDetails, replaceWith) => {
  const filePath = enumFolderPath + fileName;
  const outputExists = fs.existsSync(filePath);
  if (!outputExists) throw new Error(`${fileName} enum not found! ${filePath}`);

  const verificationDetailsString = fs.readFileSync(filePath, "utf-8");

  // replace last bracket with new line
  const verificationDetails = verificationDetailsString
    .trimEnd()
    .replace(replaceWith, newChainDetails);

  fs.writeFileSync(filePath, verificationDetails);
};
