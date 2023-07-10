
const { providers, Contract, utils } = require("ethers");
const InterestsABI = require('../package/abi/Interests.json');
const GLDTokenABI = require('../package/abi/GLDToken.json');
const contractAddress = require('../contractAddress.json');
const {DEPLOYER_PRIVATE_KEY,FROM_RPC_ENDPOINT,DEPLOYER_PRIVATE_KEY2,lendingPool_,usdt} = process.env;
const {getDeployer,deployNewFromAbi,getDeployedCantract} = require("./help");

 const ds=1;
 let balance =100;

async function main(){

  const deployer = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
  const deployer2 = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY2);

  const Interests = await hre.ethers.getContractFactory("Interests");
  const  userA  = await deployNewFromAbi(InterestsABI,Interests.bytecode,deployer,[contractAddress.valut,lendingPool_]);
  const  userB = await  getDeployedCantract(userA.address,InterestsABI,deployer2)
   //充值
   await userA.setTotalValue(balance);
   await userA.update_deposit(balance,usdt,deployer.address);
   console.log("用户A充值:",balance)
   console.log("-----------------------------------")   

   await userA.setTotalValue(balance+10);
   console.log("----N天池子总价值---:",balance+10)
   const tcs = await userA.getBalanceWithInterest(usdt,deployer.address);
   console.log("此时A用户利息:",tcs.toString())
   const tt = await userB.getBalanceWithInterest(usdt,deployer2.address);
   console.log("此时B用户利息:",tt.toString())
   console.log("-----------------------------------")

   console.log("用户B充值:",balance)
   await userB.update_deposit(balance,usdt,deployer2.address);
   console.log("-----------------------------------")  

   console.log("---N天池子总价值---",balance*2+50)
   await userA.setTotalValue(balance*2+50);  
   const balance1 = await userA.getBalanceWithInterest(usdt,deployer.address);
   console.log("此时A用户利息:",balance1.toString());
   const balance2 = await userB.getBalanceWithInterest(usdt,deployer2.address);
   console.log("此时B用户利息:",balance2.toString());
   console.log("-----------------------------------");

   //提现
  await userA.update_withdraw(50,usdt,deployer.address);
  console.log("用户A提现款",50);
  console.log("-----------------------------------")  

  await userA.setTotalValue(balance*2+50-50);  
  console.log("---N天池子总价值---:",balance*2+50-50)
  const txs = await userA.getBalanceWithInterest(usdt,deployer.address);
  console.log("此时A用户利息:",txs.toString());
  const tcss = await userB.getBalanceWithInterest(usdt,deployer2.address);
  console.log("此时b用户利息:",tcss.toString());
  console.log("-----------------------------------");

  // 股票内部划转
  await  userA.shareTransfer(deployer.address,10,false,usdt);
  console.log("用户A转股份:",10*ds);
  await  userB.shareTransfer(deployer2.address,10,true,usdt);
  console.log("B增加股份",10);

  const balancee = await userA.getBalanceWithInterest(usdt,deployer.address);
  console.log("此时A用户利息:",balancee.toString());
  const balancet = await userB.getBalanceWithInterest(usdt,deployer2.address);
  console.log("此时B用户利息:",balancet.toString());
  console.log("-----------------------------------");

  // B提取全部利息
  console.log("B用户提取利息全部利息",balancet.toString()); 
  await userB.withdrawInterest(usdt,deployer2.address);
  console.log("-----------------------------------");

  await userA.setTotalValue(balance*2+50-50-28); 
  console.log("---N天池子总价值-----:",balance*2+50-50-28)
  const tx22 = await userA.getBalanceWithInterest(usdt,deployer.address);
  console.log("此时A用户利息:",tx22.toString());
  const tx44 = await userB.getBalanceWithInterest(usdt,deployer2.address);
  console.log("此时B用户利息:",tx44.toString());
   
}
main();
