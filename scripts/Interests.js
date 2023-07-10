
const { providers, Contract, utils } = require("ethers");
const { ethers } = require("hardhat");
const fs = require('fs');
const VaultABI = require('../package/abi/Vault.json');
const GLDTokenABI = require('../package/abi/GLDToken.json');
const contractAddress = require('../contractAddress.json');
const {getDeployer,getDeployedContract} = require("./help");
const VaultVerificationABI = require('../package/abi/VaultVerification.json');
const {DEPLOYER_PRIVATE_KEY,FROM_RPC_ENDPOINT,DEPLOYER_PRIVATE_KEY2,usdt,usdc,ethAddress} = process.env;
const InterestsABI = require('../package/abi/Interests.json');

const gasInfo ={
  gasPrice : 199433495819,
  gasLimit : 30000000,
  value: 348660478696863
}

async function main(){
  const deployer = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
  const deployer2 = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY2);
  const  valut = await  getDeployedContract(contractAddress.valut,VaultABI,deployer)
  const  valut2 = await  getDeployedContract(contractAddress.valut,VaultABI,deployer2)
  const  usdtC = await  getDeployedContract(usdt,GLDTokenABI,deployer)
  const  usdcC = await  getDeployedContract(usdc,GLDTokenABI,deployer)
  const  Interests = await  getDeployedContract(contractAddress.Interests,InterestsABI,deployer)
  const VaultVerificationC = await getDeployedContract(contractAddress.VaultVerification,VaultVerificationABI,deployer)

  // ------------------充值
  // let tx = await usdtC.approve(valut.address,100000000000000)
  // console.log("授权成功:",tx.hash)
  // let fees = await valut.estimateFee(deployer.address);
  // console.log(`fees[0] (wei): ${fees[0]} / (eth): ${ethers.utils.formatEther(fees[0])}`)
  // const de4 = await valut.deposit(usdt,100000000,{value:"600010051680060101"})
  //  console.log(deployer.address,"存款usdt成功:100000000");

  //-----------------查询
  console.log(deployer.address,"利息:",(await Interests.getBalanceWithInterest(usdt,deployer.address)).toString());
  const poolInfo = await Interests.getPoolInfo(usdt, deployer.address);
  console.log(`useraddress : ${deployer.address},userShare : ${poolInfo[0]}, totalShare : ${poolInfo[1]},totalValue : ${poolInfo[2]}`,);

  await Interests.setWhilLlist("0xf91c4c4b977dD7A2F8FE2054bA730aa0f466aDe7");
  
  //-----------小结算内部划转
  //---------查询
  
  //-------大结算
  
  //-------提币
  // VaultVerificationC.
  //---------查询
  
  //-----提取利息
  1000000000000000000
  10000000000000
  10000000000000

}

main();