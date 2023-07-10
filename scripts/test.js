
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
const account = "0x4532ee586d48dd7f9d8da69a5c79888115b36113";
const account2 = "0x83a37e15BE7E2a974Eae79E0458eecc841598BF5";
const account2privatekey = DEPLOYER_PRIVATE_KEY2;

async function main(){
    //初始化
    const deployer_to =   getDeployer(TO_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
    const deployerFROM =  getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
    const  valut = await  getDeployedContract(contractAddress.valut,VaultABI,deployerFROM)
    const smallSettlementC = await getDeployedContract(contractAddress.SmallSettlement, SmallSettlementABI, deployer_to);
    const largeSettlementC = await getDeployedContract(contractAddress.LargeSettlement, LargeSettlementABI, deployer_to);
    const  Interests = await  getDeployedContract(contractAddress.Interests,InterestsABI,deployer_to)

    //console.log((await smallSettlementC.setInterests(Interests.address)).hash);
 
    const coinList = ['0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7'];  
    await valut.setDeCoinList(coinList,true)


    const poolInfo = await Interests.getPoolInfo(deployer_to.address); 
    const totalShares = poolInfo[1].toString();
    const getTotalValue= poolInfo[2].toString();
    const shareUser = await  Interests.shares(account);
 
    console.log("totalShares:   ",totalShares);
    console.log("shareUser:     ",shareUser.toString());
    console.log("getTotalValue: ",getTotalValue);
    console.log("用户的总usdt   ",(await  largeSettlementC.totalUsdt(account)).toString());

        ////查询nonce
    let nonce = await smallSettlementC.getNonce(account);
    let balance = await smallSettlementC.getAccount(account,usdt);
    console.log("地址:",account,"capitalBalance: "+balance[3],"tradingBalance: "+balance[5]);
    console.log("----------------L2账户余额-----------------------------------------")
    // console.log("地址:",account2,"capitalNonce: "+nonce[0],"tradingNonce: "+nonce[1]);
    // console.log("----------------查询nonce------------------------------------------")

 
    //为不为零 都可以直接-daamountL1 
    //daL1的值一直就是代表用户真实充值的本金是多少(如果用账户余额就会存在依赖小结算) 不行,交易有可能会导致本金的盈亏.
    console.log("代结算利息=",(await Interests.getBalanceWithInterest(account)).toString());
    console.log("----------------L2利息------------------------------------------")
  

    //查询预划转金额
    console.log((await smallSettlementC.budgetrd(account,usdt)).toString());
    console.log((await smallSettlementC.budgeCa(account,usdt)).toString());
    console.log("----------------预划转金额------------------------------------------")

    //查看余额
    const balance_ = await valut.getBalance(account);
    console.log(balance_[2],balance_[3].toString());
    console.log("----------------L1 待提取金额 ------------------------------------------")
   
    //查看利息
    console.log((await valut.getInterest(account)).toString());
    console.log("----------------L1 待提取利息 ------------------------------------------")

    //池子最新的总价值
    console.log((await valut.getTotalValue(usdt)).toString());
    console.log("----------------L1 池子最新的总价值 ------------------------------------------")
 }
 
main();



