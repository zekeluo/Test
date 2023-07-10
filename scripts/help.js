const {ethers} = require("hardhat");
const fs = require("fs");
const dotenv = require('dotenv');


function loadEnv() {
    dotenv.config();
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = process.env;
    if (!(CHAIN_NAME && RPC_ENDPOINT && DEPLOYER_PRIVATE_KEY)) {
        throw new Error("Must populate all values in .env - see .env.example for full list");
    }
    return {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY};
}

function getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY) {
    const provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
    const deployer = new ethers.Wallet(`0x${DEPLOYER_PRIVATE_KEY}`, provider);
    return deployer;
}

async function deploy(wallet,name, args = []) {
  const Implementation = await ethers.getContractFactory(wallet,name);
  const contract = await Implementation.deploy(...args,{gasPrice:164726163});
  return contract.deployed();
}

async function approve(signer, tokenContract, to, tokenId) {
  const data = encodeData(tokenContract, 'approve', [to, tokenId]);

  return signer.sendTransaction({
    to: tokenContract.address,
    data,
  });
}

function encodeData(contract, functionName, args) {
  const func = contract.interface.getFunction(functionName);
  return contract.interface.encodeFunctionData(func, args);
}

function eth(num) {
  return ethers.utils.parseEther(num.toString());
}

function getDeployedDependenceAddresses() {
    const directory = "./deploy/deployed-contracts";
    const filename = `${directory}/deployed-dependencies.json`;
    let contractAddresses;
    try {
        contractAddresses = JSON.parse(fs.readFileSync(filename));
    } catch (e) {
        console.error(e);
        contractAddresses = {
            chain: "local",
        };
    }
    return {directory, filename, contractAddresses};
}

function getDeployedAddresses(CHAIN_NAME) {
    const directory = `./package/${CHAIN_NAME}/address`;
    const filename = `${directory}/${CHAIN_NAME}.json`;
    let contractAddresses;
    try {
        contractAddresses = JSON.parse(fs.readFileSync(filename));
    } catch (e) {
        console.error(e);
        contractAddresses = {
            chain: CHAIN_NAME,
        };
    }
    return {directory, filename, contractAddresses};
}

function getABI(CHAIN_NAME) {
    const directory = `./package/${CHAIN_NAME}/address`;
    const filename = `${directory}/${CHAIN_NAME}.json`;
    let contractAddresses;
    try {
        contractAddresses = JSON.parse(fs.readFileSync(filename));
    } catch (e) {
        console.error(e);
        contractAddresses = {
            chain: CHAIN_NAME,
        };
    }
    return {directory, filename, contractAddresses};
}

function getBytecode(CHAIN_NAME) {
    const directory = `./package/address`;
    const filename = `${directory}/${CHAIN_NAME}.json`;
    let contractAddresses;
    try {
        contractAddresses = JSON.parse(fs.readFileSync(filename));
    } catch (e) {
        console.error(e);
        contractAddresses = {
            chain: CHAIN_NAME,
        };
    }
    return {directory, filename, contractAddresses};
}

function writeDeployedAddresses(directory, filename, addresses) {
    fs.mkdirSync(directory, {recursive: true});
    fs.writeFileSync(
        filename,
        JSON.stringify(addresses, null, 2),
    );
}


async function deployNewFromAbi (abi, bytecode, signer, args = []){
    const C = new ethers.ContractFactory(abi, bytecode, signer)
    if (args) {
        return C.deploy(...args)
    } else {
        return C.deploy()
    }
}

async function  getDeployedContract(contractAddress, abi, wallet) {
    let contract = new ethers.Contract(contractAddress, abi, wallet);
    return contract;
}

module.exports = {
    getDeployedContract,
    deployNewFromAbi,
    loadEnv,
    getDeployer,
    deploy,
    approve,
    encodeData,
    eth,
    getDeployedDependenceAddresses,
    getDeployedAddresses,
    writeDeployedAddresses
};
