"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const signature_1 = require("./signature");
const main = async () => {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.log("Usage: npx ts-node sign.ts <privateKey> <chainID> e.g npx ts-node sign.ts 0x1234 1");
        process.exit(1);
    }
    const privateKey = args[0];
    const chainId = parseInt(args[1]);
    await (0, signature_1.sign)(privateKey, chainId);
};
main();
