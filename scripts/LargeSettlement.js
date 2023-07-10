const fs = require('fs');
const VaultABI = require('../package/abi/Vault.json');
const SmallSettlementABI = require('../package/abi/SmallSettlement.json');
const LargeSettlementABI = require('../package/abi/LargeSettlement.json');
const InterestsABI = require('../package/abi/Interests.json');
const contractAddress = require('../contractAddress.json');
const Web3 = require("web3");
const web3 = new Web3(new Web3.providers.HttpProvider("https://arb-goerli.g.alchemy.com/v2/WjxNhgUo7ROpGEpjXBeWDTa61tPf2qBc"));
const {getDeployer,getDeployedContract} = require("./help");
const {DEPLOYER_PRIVATE_KEY,DEPLOYER_PRIVATE_KEY2,FROM_RPC_ENDPOINT,TO_RPC_ENDPOINT,lendingPool_,L1_ENDPOINTS,L2_ENDPOINTS,L1_dstChainId,L2_dstChainId,usdt,usdtethAddress} = process.env;

// Your initial variables and constants
const account = "0x0a64bc73793faf399adb51ebad204acb11f0ae64";
const account2 = "0x83a37e15BE7E2a974Eae79E0458eecc841598BF5";
const account2privatekey = DEPLOYER_PRIVATE_KEY2;

const gasInfo ={
    // gasPrice : 19933495819,
    // gasLimit : 30000000,
    value: "90000105168006011"
  }

async function main(){
    //初始化
    const deployer_to =   getDeployer(TO_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
    const deployerFROM =  getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
    const smallSettlementC = await getDeployedContract(contractAddress.SmallSettlement, SmallSettlementABI, deployer_to);
    const largeSettlementC = await getDeployedContract(contractAddress.LargeSettlement, LargeSettlementABI, deployer_to);
    const  Interests = await  getDeployedContract(contractAddress.Interests,InterestsABI,deployer_to)
  
    // const poolInfo = await Interests.getPoolInfo(deployer_to.address);
 
    // let getdata =await smallSettlementC.getData(account);
    // let data = await signature(getdata,DEPLOYER_PRIVATE_KEY);

    // let checkout = await largeSettlementC.checkOut(account,data,usdt,gasInfo);
    // console.log("大结算hash:",checkout.hash);


    // // //用户自己大结算
    let checkout = await largeSettlementC.checkOutForUser(gasInfo);
    console.log("大结算hash:",checkout.hash);    
     
 }

main();

async function signature(valuesdata,nodekey){
    let values = {};
    values.user = valuesdata[0];
    values.capitaMerkleRoot = valuesdata[1];
    values.coinList = ['0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7']; 
    values.withdrawnValues = ['100000000000'];
    values.totalShares = valuesdata[2];
    values.shares = valuesdata[3];
    values.nativeFee = valuesdata[4];
    values.checkOutType = 1; // 1 提币 2 利息

    let message = ethers.utils.solidityKeccak256(
    ["address","bytes32","address[]","uint256[]","uint256","uint256","uint256","uint8"],
    [values.user,values.capitaMerkleRoot, values.coinList, values.withdrawnValues,values.totalShares,values.shares,values.nativeFee,values.checkOutType]);

    let signatureUser = await web3.eth.accounts.sign(message, nodekey);
    values.messageHash = message;
    values.signature = signatureUser.signature;

    return values;
}


