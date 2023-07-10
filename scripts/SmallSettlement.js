const fs = require('fs');
const VaultABI = require('../package/abi/Vault.json');
const SmallSettlementABI = require('../package/abi/SmallSettlement.json');
const LargeSettlementABI = require('../package/abi/LargeSettlement.json');
const InterestsABI = require('../package/abi/Interests.json');
const contractAddress = require('../contractAddress.json');
const Web3 = require("web3");
const web3 = new Web3(new Web3.providers.HttpProvider("https://arb-goerli.g.alchemy.com/v2/WjxNhgUo7ROpGEpjXBeWDTa61tPf2qBc"));
const {getDeployer,getDeployedContract} = require("./help");
const {DEPLOYER_PRIVATE_KEY,DEPLOYER_PRIVATE_KEY2,FROM_RPC_ENDPOINT,TO_RPC_ENDPOINT,usdt,buin} = process.env;

// Your initial variables and constants
const account = "0x0a64bc73793faf399adb51ebad204acb11f0ae64";
const account2 = "0x83a37e15BE7E2a974Eae79E0458eecc841598BF5";
const account2privatekey = DEPLOYER_PRIVATE_KEY2;

async function main(){
    //初始化
    const deployer_to =   getDeployer(TO_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
    const deployerFROM =  getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
    const smallSettlementC = await getDeployedContract(contractAddress.SmallSettlement, SmallSettlementABI, deployer_to);
    const largeSettlementC = await getDeployedContract(contractAddress.LargeSettlement, LargeSettlementABI, deployer_to);
    const  Interests = await  getDeployedContract(contractAddress.Interests,InterestsABI,deployer_to)
    // const poolInfo = await Interests.getPoolInfo(deployer_to.address);
    // console.log(poolInfo[2].toString());
   
      // //充值accoun
     await deposit(smallSettlementC,account,DEPLOYER_PRIVATE_KEY,"1000000000000000000000000000000",usdt,1,"A32522233");
    //  await deposit(smallSettlementC,account,DEPLOYER_PRIVATE_KEY,100000000000,buin,2,"A234");

// //     // // //预划转 资金=》交易
         await withholding(smallSettlementC,account,["0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7"],["10000000"],1,DEPLOYER_PRIVATE_KEY,DEPLOYER_PRIVATE_KEY);
// // //        await withholding(smallSettlementC,account,["0x68b4a1c180f89818D4b90a51875299716a94C753"],["10000000"],1,DEPLOYER_PRIVATE_KEY,DEPLOYER_PRIVATE_KEY);

// // // //     // //划转 资金=》交易
         await transfer(smallSettlementC,account,["10000000"],["0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7"],DEPLOYER_PRIVATE_KEY,2,1,"A234223");
// // //        await transfer(smallSettlementC,account,["10000000"],["0x68b4a1c180f89818D4b90a51875299716a94C753"],DEPLOYER_PRIVATE_KEY,4,2,"A232423");

    // // //交易
    //  await trading(smallSettlementC,account,account2,DEPLOYER_PRIVATE_KEY,account2privatekey,2,2);
    
}

main();

// 上传充值订单
async function deposit(smallSettlementC,userAddress,nodePrivateKey,coinAmount,coinAddress,nonce,id){
    let billArray = [];
    let bill = {};
    bill.id = id;
    bill.user = userAddress;
    bill.balance =["100000000"];
    bill.coinType =["0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7"];
    bill.actionType = true;
    bill.coinAmount = coinAmount;
    bill.coinAddress = coinAddress;
    bill.isNegative = true;
    bill.isNegativeforTransfer = true;
    bill.nonce = nonce;
    bill.orderType = 1;

    let message = ethers.utils.solidityKeccak256(
    ["string", "address","uint256[]","address[]","bool","uint256", "address", "bool","bool","uint16"],
    [bill.id,bill.user,bill.balance, bill.coinType, bill.actionType, bill.coinAmount, bill.coinAddress, bill.isNegative, bill.isNegativeforTransfer, bill.orderType]);

    let nodeSignature = await web3.eth.accounts.sign(message, nodePrivateKey);
    bill.messageHash = message;
    bill.signature = nodeSignature.signature;

    billArray.push(bill);

    let data = await smallSettlementC.verificationBook(billArray, userAddress);
    console.log("充值订单:",data.hash)
}

//usdt 
async function transfer(smallSettlementC,userAddress,balance,coinType,nodePrivateKey,canonce,tranonce,id){
    let billArray = [];
    let bill = {};
    let bill2 ={};

    //资金账户
    bill.id =id;
    bill.user = userAddress;
    bill.balance = balance ;
    bill.coinType = coinType;
    bill.actionType = true;  //操作资金账户
    bill.coinAmount = "100";
    bill.coinAddress = "0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7";
    bill.isNegative = true;  
    bill.isNegativeforTransfer = true;  //是否-
    bill.nonce = canonce;
    bill.orderType = 3;

    let message = ethers.utils.solidityKeccak256(
    ["string", "address","uint256[]","address[]","bool","uint256", "address", "bool","bool","uint16"],
    [bill.id,bill.user,bill.balance, bill.coinType, bill.actionType, bill.coinAmount, bill.coinAddress, bill.isNegative, bill.isNegativeforTransfer, bill.orderType]);

    let nodeSignature = await web3.eth.accounts.sign(message, nodePrivateKey);
    bill.messageHash = message;
    bill.signature = nodeSignature.signature;

    //交易账户
    bill2.id = id+"A2210002";
    bill2.user = userAddress;
    bill2.balance = balance;
    bill2.coinType = coinType;
    bill2.actionType = false;
    bill2.coinAmount = "100";
    bill2.coinAddress = "0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7";
    bill2.isNegative = true;
    bill2.isNegativeforTransfer = false;
    bill2.nonce = tranonce;
    bill2.orderType = 3;

    let message2 = ethers.utils.solidityKeccak256(
    ["string", "address","uint256[]","address[]","bool","uint256", "address", "bool","bool","uint16"],
    [bill2.id,bill2.user,bill2.balance, bill2.coinType, bill2.actionType, bill2.coinAmount, bill2.coinAddress, bill2.isNegative, bill2.isNegativeforTransfer, bill2.orderType]);

    let nodeSignature2 = await web3.eth.accounts.sign(message2, nodePrivateKey);
    bill2.messageHash = message2;
    bill2.signature = nodeSignature2.signature;

    billArray.push(bill);
    billArray.push(bill2);

    let data = await smallSettlementC.verificationBook(billArray, userAddress);
    console.log("划转成功:",data.hash);
}

async function trading(smallSettlementC,userA,userB,userAk,userBk,userAnoce,userBnonce){
    let billArray = [];
    let bills =[];

    let bill = {};
    let bill2 = {};

    //用户A 减去100usdt ,增加1eth
    bill.id = "A10001";
    bill.user = userA;
    bill.goodsAmount = "1000";
    bill.goodsAddress = "0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7";
    bill.isNegativeforGoods = false;
    bill.coinAmount = "1000";
    bill.coinAddress = "0x68b4a1c180f89818D4b90a51875299716a94C753";
    bill.isNegativeforCoin = true;
    bill.totalValue = 100;
    bill.fee = 1;
    bill.feeCoin = "0x68b4a1c180f89818D4b90a51875299716a94C753";
    bill.nonce = userAnoce;

    const messageHash = ethers.utils.solidityKeccak256(
    ["string", "address", "uint256", "address", "bool", "uint256", "address", "bool","uint256",],
    [ bill.id, bill.user, bill.goodsAmount, bill.goodsAddress,  bill.isNegativeforGoods, bill.coinAmount, bill.coinAddress, bill.isNegativeforCoin, bill.totalValue]
    );
    let nodeSignature = await web3.eth.accounts.sign(messageHash, userAk);
    bill.messageHash = messageHash;
    bill.signature = nodeSignature.signature;

    //用户B 增加100usdt, 减去1eth
    bill2.id = "A10001";
    bill2.user = userB;
    bill2.goodsAmount = "1000";
    bill2.goodsAddress = "0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7";
    bill2.isNegativeforGoods = true;
    bill2.coinAmount = "1000";
    bill2.coinAddress = "0x68b4a1c180f89818D4b90a51875299716a94C753";
    bill2.isNegativeforCoin = false;
    bill2.totalValue = 100;
    bill2.fee = 1;
    bill2.feeCoin = "0x0000000000000000000000000000000000000000";
    bill2.nonce = userBnonce;

    const messageHash2 = ethers.utils.solidityKeccak256(
    ["string", "address", "uint256", "address", "bool", "uint256", "address", "bool","uint256",],
    [ bill2.id, bill2.user, bill2.goodsAmount, bill2.goodsAddress, bill2.isNegativeforGoods, bill2.coinAmount, bill2.coinAddress, bill2.isNegativeforCoin,bill2.totalValue]
    );

    let nodeSignature2 = await web3.eth.accounts.sign(messageHash2, userBk);
    bill2.messageHash = messageHash2;
    bill2.signature = nodeSignature2.signature;

    bills.push(bill);
    bills.push(bill2);

    billArray.push(bills);

    let data = await smallSettlementC.verificationBookFoTrade([billArray]);
    console.log("上传交易成功:",data.hash);

}

// 预划转订单
async function withholding(smallSettlementC,user,addList,amount,coinType,userPrivateKey,nodePrivateKey){
    let bill = {};
    bill.addList = addList;
    bill.amount = amount ;
    bill.coinType = coinType;  
    bill.user = user;

    let message = ethers.utils.solidityKeccak256(
    ["address[]","uint256[]","bool","address"],
    [bill.addList,bill.amount, bill.coinType, bill.user]);

    let signatureUser = await web3.eth.accounts.sign(message, userPrivateKey);
    bill.messageHashUser = message;
    bill.signatureUser = signatureUser.signature;

    let signatureNode = await web3.eth.accounts.sign(message, nodePrivateKey);
    bill.messageHashNode = message;
    bill.signatureNode = signatureNode.signature;

    let data = await smallSettlementC.withholding(bill);
    console.log("划转订单:",data.hash)
}






