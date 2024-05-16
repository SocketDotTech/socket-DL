import fs from "fs";
import path from "path";
import { artifacts, ethers } from "hardhat";
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
  BytesLike,
} from "ethers/lib/utils";
import {
  TransactionResponse,
  TransactionReceipt,
} from "@ethersproject/abstract-provider";
import { Address } from "hardhat-deploy/dist/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { signUserOp } from "./signature";
import { KINTO_DATA } from "./constants.json";

// gas estimation helpers
const COST_OF_POST = parseUnits("200000", "wei");

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

type GasParams = {
  gasLimit?: BigNumber;
  maxFeePerGas?: BigNumber;
  maxPriorityFeePerGas?: BigNumber;
};

type UserOpGasParams = {
  callGasLimit: number;
  verificationGasLimit: number;
  preVerificationGas: number;
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
  return (await ethers.getContractFactory(contractName))
    .attach(contractAddr)
    .connect(signer);
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
  const { contracts: kinto, userOpGasParams } = KINTO_DATA;
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
  // const salt: BytesLike = randomBytes(32); // or use fixed ethers.utils.hexZeroPad("0x", 32);
  const salt: BytesLike = ethers.utils.hexZeroPad("0x", 32);
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
  const paymasterAddr = "0x"; // if using paymaster replace with `paymaster.address`
  userOps[0] = await createUserOp(
    chainId,
    kintoWallet.address,
    entryPoint.address,
    paymasterAddr,
    nonce,
    executeCalldata
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
      paymasterAddr,
      nonce,
      executeCalldata
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
      paymasterAddr,
      nonce,
      calldataClaimOwner
    );
  }

  // gas check
  const feeData = await signer.provider.getFeeData();
  const maxFeePerGas = feeData.maxFeePerGas;
  const requiredPrefund = calculateRequiredPrefund(
    userOpGasParams,
    maxFeePerGas
  );
  const ethMaxCost = calculateEthMaxCost(requiredPrefund, maxFeePerGas).mul(
    userOps.length
  );

  // get balance of kinto wallet
  const kintoWalletBalance = await signer.provider.getBalance(
    kintoWallet.address
  );
  if (kintoWalletBalance.lt(ethMaxCost))
    throw new Error(
      `Kinto Wallet balance ${kintoWalletBalance} is less than the required ETH max cost ${ethMaxCost.toString()}`
    );
  // if (paymasterBalance.lt(ethMaxCost)) throw new Error(`Paymaster balance ${paymasterBalance} is less than the required ETH max cost ${ethMaxCost.toString()}`);

  // submit user operation to the EntryPoint
  await handleOps(userOps, signer);

  console.log(`- ${name} contract deployed @ ${contractAddr}`);
  try {
    const owner = await (await getInstance(contractName, contractAddr))
      .connect(signer)
      .owner();
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
  // const salt: BytesLike = randomBytes(32); // or use fixed ethers.utils.hexZeroPad("0x", 32);
  const salt: BytesLike = ethers.utils.hexZeroPad("0x", 32);

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

const isKinto = (chainId: number): boolean => chainId === KINTO_DATA.chainId;

const handleOps = async (
  userOps: PopulatedTransaction[] | UserOperation[],
  signer: Signer | Wallet,
  gasParams: GasParams = {},
  withPaymaster = false
): Promise<TransactionReceipt> => {
  const { contracts: kinto } = KINTO_DATA;

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
        withPaymaster ? paymaster.address : "0x",
        nonce,
        calldata
      );
      nonce = nonce.add(1);
    }
    userOps = ops;
  }

  gasParams = {
    maxPriorityFeePerGas: parseUnits("1.1", "gwei"),
    maxFeePerGas: parseUnits("1.1", "gwei"),
    gasLimit: BigNumber.from("400000000"),
  };
  const txResponse: TransactionResponse = await entryPoint.handleOps(
    userOps,
    await signer.getAddress(),
    {
      // gasParams,
      type: 1, // non EIP-1559
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
  const { contracts: kinto } = KINTO_DATA;
  const kintoWallet = new ethers.Contract(
    process.env.SOCKET_OWNER_ADDRESS,
    kinto.kintoWallet.abi,
    signer
  );

  if (await kintoWallet.appWhitelist(app)) {
    console.log(`- Contract is already whitelisted on Kinto Wallet`);
    return;
  } else {
    const txRequest = await kintoWallet.populateTransaction.whitelistApp(
      [app],
      [true],
      {
        gasLimit: 4_000_000,
      }
    );

    const tx = await handleOps([txRequest], signer);
    console.log(`- Contract succesfully whitelisted on Kinto Wallet`);
    return tx;
  }
};

const setFunderWhitelist = async (
  funders: Address[],
  isWhitelisted: boolean[],
  signer: SignerWithAddress | Wallet
) => {
  const { contracts: kinto } = KINTO_DATA;
  const kintoWallet = new ethers.Contract(
    process.env.SOCKET_OWNER_ADDRESS,
    kinto.kintoWallet.abi,
    signer
  );
  // for each funder, check which ones are not whitelistd (isFunderWhitelisted)
  // and add them to an array to be passed to setFunderWhitelist
  for (let i = 0; i < funders.length; i++) {
    if (
      (await kintoWallet.isFunderWhitelisted(funders[i])) === isWhitelisted[i]
    ) {
      console.log(
        `- Funder ${funders[i]} is already ${
          isWhitelisted[i] ? "whitelisted" : "blacklisted"
        }`
      );
      funders.splice(i, 1);
      isWhitelisted.splice(i, 1);
    }
  }

  // "function setFunderWhitelist(address[] calldata newWhitelist, bool[] calldata flags)",
  const txRequest = await kintoWallet.populateTransaction.setFunderWhitelist(
    funders,
    isWhitelisted
  );

  const tx = await handleOps([txRequest], signer);
  console.log(`- Funders whitelist succesfully updated`);
  return tx;
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
  callData: string
): Promise<UserOperation> => {
  const { callGasLimit, verificationGasLimit, preVerificationGas } =
    KINTO_DATA.userOpGasParams as UserOpGasParams;
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
    paymasterAndData: paymaster,
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
  gasParams,
  maxFeePerGas: BigNumber,
  multiplier = 1 // 2 if paymaster is used
): BigNumber => {
  const { callGasLimit, verificationGasLimit, preVerificationGas } = gasParams;
  const requiredGas =
    callGasLimit + verificationGasLimit * multiplier + preVerificationGas;
  const requiredPrefund = BigNumber.from(requiredGas).mul(maxFeePerGas);
  return requiredPrefund;
};

const calculateEthMaxCost = (
  requiredPrefund: BigNumber,
  maxFeePerGas: BigNumber
): BigNumber => requiredPrefund.add(COST_OF_POST.mul(maxFeePerGas));

const estimateGas = async (
  signer: Signer,
  entryPoint: Contract,
  userOps: UserOperation[]
) => {
  const feeData = await signer.provider.getFeeData();

  let gasParams: GasParams;
  try {
    const gasLimit = await entryPoint.estimateGas.handleOps(
      userOps,
      await signer.getAddress()
    );
    const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
    const maxFeePerGas = feeData.maxFeePerGas;
    gasParams = {
      gasLimit,
      maxPriorityFeePerGas,
      maxFeePerGas,
    };
  } catch (error) {
    console.log("- Error estimating gas limit, using default values");
    gasParams = {
      maxPriorityFeePerGas: parseUnits("1.1", "gwei"),
      maxFeePerGas: parseUnits("1.1", "gwei"),
      gasLimit: BigNumber.from("400000000"),
    };
  }

  const txCost = gasParams.gasLimit.mul(gasParams.maxFeePerGas);
  console.log("- Estimated gas cost (ETH):", ethers.utils.formatEther(txCost));

  return gasParams;
};

export const getInstance = async (
  contractName: string,
  address: Address
): Promise<Contract> => {
  const artifact = await artifacts.readArtifact(contractName);
  return new ethers.Contract(address, artifact.abi);
};

// const getInstance = async (
//   contractName: string,
//   address: Address,
//   signer: SignerWithAddress | Wallet
// ): Promise<Contract> =>
//   (await ethers.getContractFactory(contractName))
//     .attach(address)
//     .connect(signer);

export {
  isKinto,
  setFunderWhitelist,
  handleOps,
  deployOnKinto,
  whitelistApp,
  estimateGas,
};
