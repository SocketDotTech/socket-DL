import fs from "fs";
import path from "path";
import { ethers } from "hardhat";
import {
  Wallet,
  Contract,
  BigNumber,
  PopulatedTransaction,
  Signer,
} from "ethers";
import {
  defaultAbiCoder,
  keccak256,
  parseUnits,
  Interface,
  hexlify,
  id,
  getCreate2Address,
} from "ethers/lib/utils";
import {
  TransactionResponse,
  TransactionReceipt,
} from "@ethersproject/abstract-provider";
import { Address } from "hardhat-deploy/dist/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { signUserOp } from "./signature";
import { KINTO_DATA } from "./constants.json";
import { randomBytes } from "crypto";

// gas estimation helpers
const COST_OF_POST = parseUnits("200000", "wei");
const MAX_FEE_PER_GAS = parseUnits("1", "gwei");

type UserOperation = {
  sender: Address;
  nonce: BigNumber;
  initCode: string;
  callData: string;
  callGasLimit: number;
  verificationGasLimit: number;
  preVerificationGas: number;
  maxFeePerGas: BigNumber;
  maxPriorityFeePerGas: BigNumber;
  paymasterAndData: string;
  signature: string;
};

// deployer utils

const deployOnKinto = async (
  contractName: string,
  args: Array<string>,
  signer: SignerWithAddress | Wallet
): Promise<Contract> => {
  let contractAddr: Address;
  const argTypes = await extractArgTypes(contractName);

  // if the contract inherits from Socket's custom 2-step Ownable contract, we deploy it via KintoDeployer
  if (await isOwnable(contractName)) {
    contractAddr = await deployWithDeployer(
      contractName,
      argTypes,
      args,
      signer
    );
  } else {
    // otherwise, we deploy it via Kinto's factory
    contractAddr = await deployWithKintoFactory(
      contractName,
      argTypes,
      args,
      signer
    );
  }

  // whitelist contract on Socket's kinto wallet
  await whitelistApp(contractAddr, signer);

  return (await ethers.getContractFactory(contractName)).attach(contractAddr);
};

const getOrDeployDeployer = async (signer: SignerWithAddress | Wallet) => {
  let deployer = KINTO_DATA.contracts.deployer.address;
  if (!deployer || deployer === "0x") {
    // if deployer address is not set, deploy it and save it
    deployer = await deployWithKintoFactory("KintoDeployer", [], [], signer);

    // write address in constants.ts using fs
    KINTO_DATA.contracts.deployer.address = deployer;
    const filePath = path.join(__dirname, "constants.json");
    fs.writeFileSync(filePath, JSON.stringify({ KINTO_DATA }, null, 2));

    // whitelist KintoDeployer on Socket's kinto wallet
    await whitelistApp(deployer, signer);
  }
  return deployer;
};

const deployWithDeployer = async (
  contractName: string,
  argTypes: Array<any>,
  args: Array<any>,
  signer: SignerWithAddress | Wallet
): Promise<Address> => {
  const chainId = await signer.getChainId();
  const { contracts: kinto, gasParams } = KINTO_DATA;
  const deployer = await getOrDeployDeployer(signer);
  console.log(`Deployer address: ${deployer}`);

  const kintoWallet = new ethers.Contract(
    process.env.SOCKET_OWNER_ADDRESS,
    kinto.kintoWallet.abi,
    signer
  );
  const entryPoint = new ethers.Contract(
    kinto.entryPoint.address,
    kinto.entryPoint.abi,
    signer
  );
  const paymaster = new ethers.Contract(
    kinto.paymaster.address,
    kinto.paymaster.abi,
    signer
  );

  const name = contractName.split(":")[1] || contractName;
  console.log(
    `\nDeploying ${name} contract via deployer @ ${deployer} handleOps from Kinto Wallet @ ${kintoWallet.address} and signer @ ${signer.address}`
  );

  //// (1). deploy contract

  // generate bytecode to deploy contract
  console.log(`- ${name} contract will be deployed with args`, args);
  const encodedArgs = defaultAbiCoder.encode(argTypes, args);
  const contractBytecode = (await ethers.getContractFactory(contractName))
    .bytecode;
  const contractBytecodeWithConstructor =
    contractBytecode + encodedArgs.substring(2); // remove the '0x' prefix

  // encode the deployer `deploy` call
  const salt = randomBytes(32);
  const deployerInterface = new Interface(kinto.deployer.abi);
  const deployCalldata = deployerInterface.encodeFunctionData("deploy", [
    kintoWallet.address,
    contractBytecodeWithConstructor,
    salt,
  ]);

  // encode KintoWallet's `execute` call
  const kintoWalletInterface = new Interface(kinto.kintoWallet.abi);
  let executeCalldata = kintoWalletInterface.encodeFunctionData("execute", [
    deployer,
    0,
    deployCalldata,
  ]);

  let nonce: BigNumber = await kintoWallet.getNonce();
  const userOps = [];
  userOps[0] = await createUserOp(
    chainId,
    kintoWallet.address,
    entryPoint.address,
    paymaster.address,
    nonce,
    executeCalldata,
    gasParams
  );

  // compute the contract address
  const contractAddr = getCreate2Address(
    deployer,
    salt,
    keccak256(contractBytecodeWithConstructor)
  );

  if (await needsNomination(contractName)) {
    console.log(
      `- ${name} contract will nominate ${kintoWallet.address} for ownership`
    );

    //// (2). whitelist the contract
    // encode KintoWallet's `whitelistApp` call
    const whitelistAppCalldata = kintoWalletInterface.encodeFunctionData(
      "whitelistApp",
      [[contractAddr], [true]]
    );

    // encode the KintoWallet `execute` call
    nonce = nonce.add(1);
    executeCalldata = kintoWalletInterface.encodeFunctionData("execute", [
      kintoWallet.address,
      0,
      whitelistAppCalldata,
    ]);
    userOps[1] = await createUserOp(
      chainId,
      kintoWallet.address,
      entryPoint.address,
      paymaster.address,
      nonce,
      executeCalldata,
      gasParams
    );

    //// (3). claim ownership

    // encode the contract `claimOwner` call
    const contractInterface = (await ethers.getContractFactory(contractName))
      .interface;
    const claimOwnerCalldata =
      contractInterface.encodeFunctionData("claimOwner");

    // encode the KintoWallet `execute` call
    nonce = nonce.add(1);
    const calldataClaimOwner = kintoWalletInterface.encodeFunctionData(
      "execute",
      [contractAddr, 0, claimOwnerCalldata]
    );
    userOps[2] = await createUserOp(
      chainId,
      kintoWallet.address,
      entryPoint.address,
      paymaster.address,
      nonce,
      calldataClaimOwner,
      gasParams
    );
  }

  // gas check
  // const requiredPrefund = calculateRequiredPrefund(callGasLimit, verificationGasLimit, preVerificationGas);
  // const ethMaxCost = calculateEthMaxCost(requiredPrefund);
  // const paymasterBalance = await paymaster.balances(deployer);
  // if (paymasterBalance.lt(ethMaxCost)) throw new Error(`Paymaster balance ${paymasterBalance} is less than the required ETH max cost ${ethMaxCost.toString()}`);

  // submit user operation to the EntryPoint
  await handleOps(userOps, signer);

  console.log(`- ${name} contract deployed @ ${contractAddr}`);
  try {
    const owner = await (await getInstance(contractName, contractAddr)).owner();
    console.log(`- ${name} contract owner is ${owner}`);
  } catch (error) {
    console.error("Error getting owner:", error);
  }
  return contractAddr;
};

const deployWithKintoFactory = async (
  contractName: string,
  argTypes: Array<any>,
  args: Array<any>,
  signer: SignerWithAddress | Wallet
): Promise<Address> => {
  console.log(`\nDeploying ${contractName} contract using Kinto's factory`);
  const factory = new ethers.Contract(
    KINTO_DATA.contracts.factory.address,
    KINTO_DATA.contracts.factory.abi,
    signer
  );

  // prepare constructor arguments and encode them along with the bytecode
  console.log("Deploying contract with args", args);
  const encodedArgs = defaultAbiCoder.encode(argTypes, args);
  const bytecode = (await ethers.getContractFactory(contractName)).bytecode;
  const bytecodeWithConstructor = bytecode + encodedArgs.substring(2); //remove the '0x' prefix
  const salt = randomBytes(32);

  // deploy contract using Kinto's factory
  const create2Address = getCreate2Address(
    factory.address,
    salt,
    keccak256(bytecodeWithConstructor)
  );
  await (
    await factory.deployContract(
      signer.address,
      0,
      bytecodeWithConstructor,
      salt
    )
  ).wait();
  console.log("Contract deployed @", create2Address);
  return create2Address;
};

// other utils

const isKinto = async (chainId: number): Promise<boolean> =>
  chainId === KINTO_DATA.chainId;

const handleOps = async (
  userOps: PopulatedTransaction[] | UserOperation[],
  signer: Signer | Wallet
): Promise<TransactionReceipt> => {
  const { contracts: kinto, gasParams } = KINTO_DATA;

  const entryPoint = new ethers.Contract(
    kinto.entryPoint.address,
    kinto.entryPoint.abi,
    signer
  );
  const paymaster = new ethers.Contract(
    kinto.paymaster.address,
    kinto.paymaster.abi,
    signer
  );
  const kintoWallet = new ethers.Contract(
    process.env.SOCKET_OWNER_ADDRESS,
    kinto.kintoWallet.abi,
    signer
  );
  const kintoWalletInterface = new Interface(kinto.kintoWallet.abi);

  // convert into UserOperation array if not already
  if (!isUserOpArray(userOps)) {
    // encode the contract function to be called
    const ops = [];
    let nonce = await kintoWallet.getNonce();
    for (let i = 0; i < userOps.length; i++) {
      const calldata = kintoWalletInterface.encodeFunctionData("execute", [
        userOps[i].to,
        0,
        userOps[i].data,
      ]);
      ops[i] = await createUserOp(
        await signer.getChainId(),
        kintoWallet.address,
        entryPoint.address,
        paymaster.address,
        nonce,
        calldata,
        gasParams
      );
      nonce = nonce.add(1);
    }
    userOps = ops;
  }

  const txResponse: TransactionResponse = await entryPoint.handleOps(
    userOps,
    await signer.getAddress(),
    {
      maxPriorityFeePerGas: parseUnits("1", "gwei"),
      maxFeePerGas: parseUnits("1", "gwei"),
      gasLimit: "400000000",
    }
  );
  const receipt: TransactionReceipt = await txResponse.wait();
  if (hasErrors(receipt))
    throw new Error(
      "There were errors while executing the handleOps. Check the logs."
    );
  return receipt;
};

const whitelistApp = async (
  app: Address,
  signer: SignerWithAddress | Wallet
): Promise<TransactionReceipt> => {
  const { contracts: kinto, gasParams } = KINTO_DATA;
  const kintoWallet = new ethers.Contract(
    process.env.SOCKET_OWNER_ADDRESS,
    kinto.kintoWallet.abi,
    signer
  );

  const txRequest = await kintoWallet.populateTransaction.whitelistApp(
    [app],
    [true],
    {
      gasLimit: 4_000_000,
      // type,
      // gasPrice,
    }
  );

  const tx = await handleOps([txRequest], signer);
  console.log(`- Contract succesfully whitelisted on Kinto Wallet`);
  return tx;

  // const whitelistAppCalldata = kintoWalletInterface.encodeFunctionData("whitelistApp", [[contractAddr], [true]]);

  // // encode the KintoWallet `execute` call
  // nonce = nonce.add(1);
  // executeCalldata = kintoWalletInterface.encodeFunctionData("execute", [kintoWallet.address, 0, whitelistAppCalldata]);
  // userOps[1] = await createUserOp(chainId, kintoWallet.address, entryPoint.address, paymaster.address, nonce, executeCalldata, gasParams );
};

// extract argument types from constructor
const extractArgTypes = async (
  contractName: string
): Promise<Array<string>> => {
  const contractInterface = (await ethers.getContractFactory(contractName))
    .interface;

  // convert interface back to the ABI
  const abi = JSON.parse(
    contractInterface.format(ethers.utils.FormatTypes.json) as string
  );
  const constructorAbi = abi.find((element) => element.type === "constructor");

  let argTypes: string[] = [];

  if (constructorAbi && constructorAbi.inputs.length > 0) {
    // Map the inputs to their types
    argTypes = constructorAbi.inputs.map((input) => input.type);
  }

  return argTypes;
};

// check if the contract inherits from Socket's custom 2-step Ownable contract
const isOwnable = async (contractName: string): Promise<boolean> => {
  const contractInterface = (await ethers.getContractFactory(contractName))
    .interface;
  const hasOwner = contractInterface.functions["owner()"] !== undefined;
  const hasNominateOwner =
    contractInterface.functions["nominateOwner(address)"] !== undefined;
  // const hasTransferOwnership = contractInterface.functions['transferOwnership(address)'] !== undefined;
  return hasOwner && hasNominateOwner;
};

const needsNomination = async (contractName: string): Promise<boolean> => {
  const contractInterface = (await ethers.getContractFactory(contractName))
    .interface;

  // convert interface back to the ABI
  const abi = JSON.parse(
    contractInterface.format(ethers.utils.FormatTypes.json) as string
  );

  // possible owner parameter names
  const ownerParams = ["owner", "_owner", "owner_"];

  // find the constructor and check for any of the owner parameter names
  const hasOwnerParam = abi.some((item: any) => {
    return (
      item.type === "constructor" &&
      item.inputs.some((input: any) => ownerParams.includes(input.name))
    );
  });

  // if the constructor has an owner parameter, we don't need to call nominate since we pass the owner directly
  return !hasOwnerParam;
};

function isUserOpArray(array: any[]): array is UserOperation[] {
  return array.every(
    (item) => item.hasOwnProperty("sender") && item.hasOwnProperty("nonce")
  );
}

const createUserOp = async (
  chainId: number,
  sender: Address,
  entryPoint: Address,
  paymaster: Address,
  nonce: BigNumber,
  callData: string,
  gasParams: any
): Promise<object> => {
  const { callGasLimit, verificationGasLimit, preVerificationGas } = gasParams;
  const userOp = {
    sender,
    nonce,
    initCode: hexlify([]),
    callData,
    callGasLimit,
    verificationGasLimit,
    preVerificationGas,
    maxFeePerGas: parseUnits("1", "gwei"),
    maxPriorityFeePerGas: parseUnits("1", "gwei"),
    paymasterAndData: "0x",
    // paymasterAndData: paymaster,
    signature: hexlify([]),
  };

  const privateKeys = [`0x${process.env.SOCKET_SIGNER_KEY}`];
  userOp.signature = await signUserOp(userOp, entryPoint, chainId, privateKeys);
  return userOp;
};

const hasErrors = (tx: TransactionReceipt): boolean => {
  const eventSignature =
    "UserOperationRevertReason(bytes32,address,uint256,bytes)";
  const eventTopic = id(eventSignature); // hash of the event
  const eventLog = tx.logs.find((log) => log.topics[0] === eventTopic);

  if (eventLog) {
    const types = [
      "uint256", // nonce
      "bytes", // revertReason
    ];

    // decode the data
    try {
      const decoded = ethers.utils.defaultAbiCoder.decode(types, eventLog.data);
      console.log("Revert Reason (hex):", ethers.utils.hexlify(decoded[1]));
    } catch (error) {
      console.error("Error decoding data:", error);
    }

    return true;
  }
};

const calculateRequiredPrefund = (
  callGasLimit,
  verificationGasLimit,
  preVerificationGas
) => {
  const multiplier = 2; // assume paymaster is used
  const requiredGas =
    callGasLimit + verificationGasLimit * multiplier + preVerificationGas;
  const requiredPrefund = requiredGas * MAX_FEE_PER_GAS.toNumber();
  return requiredPrefund;
};

const calculateEthMaxCost = (requiredPrefund) => {
  const ethMaxCost =
    requiredPrefund + COST_OF_POST.toNumber() * MAX_FEE_PER_GAS.toNumber();
  return ethMaxCost;
};

const getInstance = async (
  contractName: string,
  address: Address
): Promise<Contract> =>
  (await ethers.getContractFactory(contractName)).attach(address);

export { isKinto, handleOps, deployOnKinto, whitelistApp };
