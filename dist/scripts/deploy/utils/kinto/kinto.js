"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.estimateGas = exports.whitelistApp = exports.deployOnKinto = exports.handleOps = exports.setFunderWhitelist = exports.isKinto = exports.getInstance = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const hardhat_1 = require("hardhat");
const ethers_1 = require("ethers");
const utils_1 = require("ethers/lib/utils");
const signature_1 = require("./signature");
const constants_json_1 = require("./constants.json");
// gas estimation helpers
const COST_OF_POST = (0, utils_1.parseUnits)("200000", "wei");
// deployer utils
const deployOnKinto = async (contractName, args, signer) => {
    let contractAddr;
    const argTypes = await extractArgTypes(contractName);
    // if the contract inherits from Socket's custom 2-step Ownable contract, we deploy it via KintoDeployer
    if (await isOwnable(contractName)) {
        contractAddr = await deployWithDeployer(contractName, argTypes, args, signer);
    }
    else {
        // otherwise, we deploy it via Kinto's factory
        contractAddr = await deployWithKintoFactory(contractName, argTypes, args, signer);
    }
    // whitelist contract on Socket's kinto wallet
    await whitelistApp(contractAddr, signer);
    return (await hardhat_1.ethers.getContractFactory(contractName))
        .attach(contractAddr)
        .connect(signer);
};
exports.deployOnKinto = deployOnKinto;
const getOrDeployDeployer = async (signer) => {
    let deployer = constants_json_1.KINTO_DATA.contracts.deployer.address;
    if (!deployer || deployer === "0x") {
        // if deployer address is not set, deploy it and save it
        deployer = await deployWithKintoFactory("KintoDeployer", [], [], signer);
        // write address in constants.ts using fs
        constants_json_1.KINTO_DATA.contracts.deployer.address = deployer;
        const filePath = path_1.default.join(__dirname, "constants.json");
        fs_1.default.writeFileSync(filePath, JSON.stringify({ KINTO_DATA: constants_json_1.KINTO_DATA }, null, 2));
        // whitelist KintoDeployer on Socket's kinto wallet
        await whitelistApp(deployer, signer);
    }
    return deployer;
};
const deployWithDeployer = async (contractName, argTypes, args, signer) => {
    const chainId = await signer.getChainId();
    const { contracts: kinto, userOpGasParams } = constants_json_1.KINTO_DATA;
    const deployer = await getOrDeployDeployer(signer);
    console.log(`Deployer address: ${deployer}`);
    const kintoWallet = new hardhat_1.ethers.Contract(process.env.SOCKET_OWNER_ADDRESS, kinto.kintoWallet.abi, signer);
    const entryPoint = new hardhat_1.ethers.Contract(kinto.entryPoint.address, kinto.entryPoint.abi, signer);
    const paymaster = new hardhat_1.ethers.Contract(kinto.paymaster.address, kinto.paymaster.abi, signer);
    const name = contractName.split(":")[1] || contractName;
    console.log(`\nDeploying ${name} contract via deployer @ ${deployer} handleOps from Kinto Wallet @ ${kintoWallet.address} and signer @ ${signer.address}`);
    //// (1). deploy contract
    // generate bytecode to deploy contract
    console.log(`- ${name} contract will be deployed with args`, args);
    const encodedArgs = utils_1.defaultAbiCoder.encode(argTypes, args);
    const contractBytecode = (await hardhat_1.ethers.getContractFactory(contractName))
        .bytecode;
    const contractBytecodeWithConstructor = contractBytecode + encodedArgs.substring(2); // remove the '0x' prefix
    // encode the deployer `deploy` call
    // const salt: BytesLike = randomBytes(32); // or use fixed ethers.utils.hexZeroPad("0x", 32);
    const salt = hardhat_1.ethers.utils.hexZeroPad("0x", 32);
    const deployerInterface = new utils_1.Interface(kinto.deployer.abi);
    const deployCalldata = deployerInterface.encodeFunctionData("deploy", [
        kintoWallet.address,
        contractBytecodeWithConstructor,
        salt,
    ]);
    // encode KintoWallet's `execute` call
    const kintoWalletInterface = new utils_1.Interface(kinto.kintoWallet.abi);
    let executeCalldata = kintoWalletInterface.encodeFunctionData("execute", [
        deployer,
        0,
        deployCalldata,
    ]);
    let nonce = await kintoWallet.getNonce();
    const userOps = [];
    const paymasterAddr = "0x"; // if using paymaster replace with `paymaster.address`
    userOps[0] = await createUserOp(chainId, kintoWallet.address, entryPoint.address, paymasterAddr, nonce, executeCalldata);
    // compute the contract address
    const contractAddr = (0, utils_1.getCreate2Address)(deployer, salt, (0, utils_1.keccak256)(contractBytecodeWithConstructor));
    if (await needsNomination(contractName)) {
        console.log(`- ${name} contract will nominate ${kintoWallet.address} for ownership`);
        //// (2). whitelist the contract
        // encode KintoWallet's `whitelistApp` call
        const whitelistAppCalldata = kintoWalletInterface.encodeFunctionData("whitelistApp", [[contractAddr], [true]]);
        // encode the KintoWallet `execute` call
        nonce = nonce.add(1);
        executeCalldata = kintoWalletInterface.encodeFunctionData("execute", [
            kintoWallet.address,
            0,
            whitelistAppCalldata,
        ]);
        userOps[1] = await createUserOp(chainId, kintoWallet.address, entryPoint.address, paymasterAddr, nonce, executeCalldata);
        //// (3). claim ownership
        // encode the contract `claimOwner` call
        const contractInterface = (await hardhat_1.ethers.getContractFactory(contractName))
            .interface;
        const claimOwnerCalldata = contractInterface.encodeFunctionData("claimOwner");
        // encode the KintoWallet `execute` call
        nonce = nonce.add(1);
        const calldataClaimOwner = kintoWalletInterface.encodeFunctionData("execute", [contractAddr, 0, claimOwnerCalldata]);
        userOps[2] = await createUserOp(chainId, kintoWallet.address, entryPoint.address, paymasterAddr, nonce, calldataClaimOwner);
    }
    // gas check
    const feeData = await signer.provider.getFeeData();
    const maxFeePerGas = feeData.maxFeePerGas;
    const requiredPrefund = calculateRequiredPrefund(userOpGasParams, maxFeePerGas);
    const ethMaxCost = calculateEthMaxCost(requiredPrefund, maxFeePerGas).mul(userOps.length);
    // get balance of kinto wallet
    const kintoWalletBalance = await signer.provider.getBalance(kintoWallet.address);
    if (kintoWalletBalance.lt(ethMaxCost))
        throw new Error(`Kinto Wallet balance ${kintoWalletBalance} is less than the required ETH max cost ${ethMaxCost.toString()}`);
    // if (paymasterBalance.lt(ethMaxCost)) throw new Error(`Paymaster balance ${paymasterBalance} is less than the required ETH max cost ${ethMaxCost.toString()}`);
    // submit user operation to the EntryPoint
    await handleOps(userOps, signer);
    console.log(`- ${name} contract deployed @ ${contractAddr}`);
    try {
        const owner = await (await (0, exports.getInstance)(contractName, contractAddr))
            .connect(signer)
            .owner();
        console.log(`- ${name} contract owner is ${owner}`);
    }
    catch (error) {
        console.error("Error getting owner:", error);
    }
    return contractAddr;
};
const deployWithKintoFactory = async (contractName, argTypes, args, signer) => {
    console.log(`\nDeploying ${contractName} contract using Kinto's factory`);
    const factory = new hardhat_1.ethers.Contract(constants_json_1.KINTO_DATA.contracts.factory.address, constants_json_1.KINTO_DATA.contracts.factory.abi, signer);
    // prepare constructor arguments and encode them along with the bytecode
    console.log("Deploying contract with args", args);
    const encodedArgs = utils_1.defaultAbiCoder.encode(argTypes, args);
    const bytecode = (await hardhat_1.ethers.getContractFactory(contractName)).bytecode;
    const bytecodeWithConstructor = bytecode + encodedArgs.substring(2); //remove the '0x' prefix
    // const salt: BytesLike = randomBytes(32); // or use fixed ethers.utils.hexZeroPad("0x", 32);
    const salt = hardhat_1.ethers.utils.hexZeroPad("0x", 32);
    // deploy contract using Kinto's factory
    const create2Address = (0, utils_1.getCreate2Address)(factory.address, salt, (0, utils_1.keccak256)(bytecodeWithConstructor));
    await (await factory.deployContract(signer.address, 0, bytecodeWithConstructor, salt)).wait();
    console.log("Contract deployed @", create2Address);
    return create2Address;
};
// other utils
const isKinto = (chainId) => chainId === constants_json_1.KINTO_DATA.chainId;
exports.isKinto = isKinto;
const handleOps = async (userOps, signer, gasParams = {}, withPaymaster = false) => {
    const { contracts: kinto } = constants_json_1.KINTO_DATA;
    const entryPoint = new hardhat_1.ethers.Contract(kinto.entryPoint.address, kinto.entryPoint.abi, signer);
    const paymaster = new hardhat_1.ethers.Contract(kinto.paymaster.address, kinto.paymaster.abi, signer);
    const kintoWallet = new hardhat_1.ethers.Contract(process.env.SOCKET_OWNER_ADDRESS, kinto.kintoWallet.abi, signer);
    const kintoWalletInterface = new utils_1.Interface(kinto.kintoWallet.abi);
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
            ops[i] = await createUserOp(await signer.getChainId(), kintoWallet.address, entryPoint.address, withPaymaster ? paymaster.address : "0x", nonce, calldata);
            nonce = nonce.add(1);
        }
        userOps = ops;
    }
    gasParams = {
        maxPriorityFeePerGas: (0, utils_1.parseUnits)("1.1", "gwei"),
        maxFeePerGas: (0, utils_1.parseUnits)("1.1", "gwei"),
        gasLimit: ethers_1.BigNumber.from("400000000"),
    };
    const txResponse = await entryPoint.handleOps(userOps, await signer.getAddress(), {
        // gasParams,
        type: 1, // non EIP-1559
    });
    const receipt = await txResponse.wait();
    if (hasErrors(receipt))
        throw new Error("There were errors while executing the handleOps. Check the logs.");
    return receipt;
};
exports.handleOps = handleOps;
const whitelistApp = async (app, signer) => {
    const { contracts: kinto } = constants_json_1.KINTO_DATA;
    const kintoWallet = new hardhat_1.ethers.Contract(process.env.SOCKET_OWNER_ADDRESS, kinto.kintoWallet.abi, signer);
    if (await kintoWallet.appWhitelist(app)) {
        console.log(`- Contract is already whitelisted on Kinto Wallet`);
        return;
    }
    else {
        const txRequest = await kintoWallet.populateTransaction.whitelistApp([app], [true], {
            gasLimit: 4000000,
        });
        const tx = await handleOps([txRequest], signer);
        console.log(`- Contract succesfully whitelisted on Kinto Wallet`);
        return tx;
    }
};
exports.whitelistApp = whitelistApp;
const setFunderWhitelist = async (funders, isWhitelisted, signer) => {
    const { contracts: kinto } = constants_json_1.KINTO_DATA;
    const kintoWallet = new hardhat_1.ethers.Contract(process.env.SOCKET_OWNER_ADDRESS, kinto.kintoWallet.abi, signer);
    console.log(`\nUpdating funders whitelist on Kinto Wallet...`);
    // for each funder, check which ones are not whitelistd (isFunderWhitelisted)
    // and add them to an array to be passed to setFunderWhitelist
    for (let i = 0; i < funders.length; i++) {
        if ((await kintoWallet.isFunderWhitelisted(funders[i])) === isWhitelisted[i]) {
            console.log(`- Funder ${funders[i]} is already ${isWhitelisted[i] ? "whitelisted" : "blacklisted"}. Skipping...`);
            funders.splice(i, 1);
            isWhitelisted.splice(i, 1);
        }
        else {
            console.log(`- Funder ${funders[i]} will be ${isWhitelisted[i] ? "whitelisted" : "blacklisted"}`);
        }
    }
    // "function setFunderWhitelist(address[] calldata newWhitelist, bool[] calldata flags)",
    const txRequest = await kintoWallet.populateTransaction.setFunderWhitelist(funders, isWhitelisted);
    const tx = await handleOps([txRequest], signer);
    console.log(`- Funders whitelist succesfully updated`);
    return tx;
};
exports.setFunderWhitelist = setFunderWhitelist;
// extract argument types from constructor
const extractArgTypes = async (contractName) => {
    const contractInterface = (await hardhat_1.ethers.getContractFactory(contractName))
        .interface;
    // convert interface back to the ABI
    const abi = JSON.parse(contractInterface.format(hardhat_1.ethers.utils.FormatTypes.json));
    const constructorAbi = abi.find((element) => element.type === "constructor");
    let argTypes = [];
    if (constructorAbi && constructorAbi.inputs.length > 0) {
        // Map the inputs to their types
        argTypes = constructorAbi.inputs.map((input) => input.type);
    }
    return argTypes;
};
// check if the contract inherits from Socket's custom 2-step Ownable contract
const isOwnable = async (contractName) => {
    const contractInterface = (await hardhat_1.ethers.getContractFactory(contractName))
        .interface;
    const hasOwner = contractInterface.functions["owner()"] !== undefined;
    const hasNominateOwner = contractInterface.functions["nominateOwner(address)"] !== undefined;
    // const hasTransferOwnership = contractInterface.functions['transferOwnership(address)'] !== undefined;
    return hasOwner && hasNominateOwner;
};
const needsNomination = async (contractName) => {
    const contractInterface = (await hardhat_1.ethers.getContractFactory(contractName))
        .interface;
    // convert interface back to the ABI
    const abi = JSON.parse(contractInterface.format(hardhat_1.ethers.utils.FormatTypes.json));
    // possible owner parameter names
    const ownerParams = ["owner", "_owner", "owner_"];
    // find the constructor and check for any of the owner parameter names
    const hasOwnerParam = abi.some((item) => {
        return (item.type === "constructor" &&
            item.inputs.some((input) => ownerParams.includes(input.name)));
    });
    // if the constructor has an owner parameter, we don't need to call nominate since we pass the owner directly
    return !hasOwnerParam;
};
function isUserOpArray(array) {
    return array.every((item) => item.hasOwnProperty("sender") && item.hasOwnProperty("nonce"));
}
const createUserOp = async (chainId, sender, entryPoint, paymaster, nonce, callData) => {
    const { callGasLimit, verificationGasLimit, preVerificationGas } = constants_json_1.KINTO_DATA.userOpGasParams;
    const userOp = {
        sender,
        nonce,
        initCode: (0, utils_1.hexlify)([]),
        callData,
        callGasLimit,
        verificationGasLimit,
        preVerificationGas,
        maxFeePerGas: (0, utils_1.parseUnits)("1", "gwei"),
        maxPriorityFeePerGas: (0, utils_1.parseUnits)("1", "gwei"),
        paymasterAndData: paymaster,
        signature: (0, utils_1.hexlify)([]),
    };
    const privateKeys = [`0x${process.env.SOCKET_SIGNER_KEY}`];
    userOp.signature = await (0, signature_1.signUserOp)(userOp, entryPoint, chainId, privateKeys);
    return userOp;
};
const hasErrors = (tx) => {
    const eventSignature = "UserOperationRevertReason(bytes32,address,uint256,bytes)";
    const eventTopic = (0, utils_1.id)(eventSignature); // hash of the event
    const eventLog = tx.logs.find((log) => log.topics[0] === eventTopic);
    if (eventLog) {
        const types = [
            "uint256",
            "bytes", // revertReason
        ];
        // decode the data
        try {
            const decoded = hardhat_1.ethers.utils.defaultAbiCoder.decode(types, eventLog.data);
            console.log("Revert Reason (hex):", hardhat_1.ethers.utils.hexlify(decoded[1]));
        }
        catch (error) {
            console.error("Error decoding data:", error);
        }
        return true;
    }
};
const calculateRequiredPrefund = (gasParams, maxFeePerGas, multiplier = 1 // 2 if paymaster is used
) => {
    const { callGasLimit, verificationGasLimit, preVerificationGas } = gasParams;
    const requiredGas = callGasLimit + verificationGasLimit * multiplier + preVerificationGas;
    const requiredPrefund = ethers_1.BigNumber.from(requiredGas).mul(maxFeePerGas);
    return requiredPrefund;
};
const calculateEthMaxCost = (requiredPrefund, maxFeePerGas) => requiredPrefund.add(COST_OF_POST.mul(maxFeePerGas));
const estimateGas = async (signer, entryPoint, userOps) => {
    const feeData = await signer.provider.getFeeData();
    let gasParams;
    try {
        const gasLimit = await entryPoint.estimateGas.handleOps(userOps, await signer.getAddress());
        const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
        const maxFeePerGas = feeData.maxFeePerGas;
        gasParams = {
            gasLimit,
            maxPriorityFeePerGas,
            maxFeePerGas,
        };
    }
    catch (error) {
        console.log("- Error estimating gas limit, using default values");
        gasParams = {
            maxPriorityFeePerGas: (0, utils_1.parseUnits)("1.1", "gwei"),
            maxFeePerGas: (0, utils_1.parseUnits)("1.1", "gwei"),
            gasLimit: ethers_1.BigNumber.from("400000000"),
        };
    }
    const txCost = gasParams.gasLimit.mul(gasParams.maxFeePerGas);
    console.log("- Estimated gas cost (ETH):", hardhat_1.ethers.utils.formatEther(txCost));
    return gasParams;
};
exports.estimateGas = estimateGas;
const getInstance = async (contractName, address) => {
    const artifact = await hardhat_1.artifacts.readArtifact(contractName);
    return new hardhat_1.ethers.Contract(address, artifact.abi);
};
exports.getInstance = getInstance;
