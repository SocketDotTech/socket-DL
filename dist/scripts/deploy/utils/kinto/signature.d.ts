import { Address } from "hardhat-deploy/dist/types";
declare const signUserOp: (userOp: any, entryPointAddress: any, chainId: any, privateKeys: any) => Promise<string>;
declare const sign: (privateKey: Address, chainId: number) => Promise<string>;
export { signUserOp, sign };
