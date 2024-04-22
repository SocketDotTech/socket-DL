import { sign } from "./signature";

const main = async () => {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.log("Usage: npx ts-node sign.ts <privateKey>");
    process.exit(1);
  }
  const privateKey = args[0];
  await sign(privateKey);
};

main();
