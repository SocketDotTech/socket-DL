"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
async function accounts(params, hre) {
    const [account] = await hre.ethers.getSigners();
    console.log(`Balance for 1st account ${await account.getAddress()}: ${await account.getBalance()}`);
}
exports.default = accounts;
