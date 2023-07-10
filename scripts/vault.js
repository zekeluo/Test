
const { providers, Contract, utils } = require("ethers");
const { ethers } = require("hardhat");
const fs = require('fs');
const VaultABI = require('../package/abi/Vault.json');
const GLDTokenABI = require('../package/abi/GLDToken.json');
const contractAddress = require('../contractAddress.json');
const {getDeployer,getDeployedContract} = require("./help");
const {DEPLOYER_PRIVATE_KEY,FROM_RPC_ENDPOINT,DEPLOYER_PRIVATE_KEY2,usdt,usdc,buin} = process.env;
const InterestsABI = require('../package/abi/Interests.json');

const gasInfo ={
  gasPrice : 19933495819,
  gasLimit : 30000000,
    value: "8006047896856355"
}

async function main(){
  const deployer = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
  const deployer2 = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY2);
  const  valut = await  getDeployedContract(contractAddress.valut,VaultABI,deployer)
  const  valut2 = await  getDeployedContract(contractAddress.valut,VaultABI,deployer2)
  const  usdtC = await  getDeployedContract(usdt,GLDTokenABI,deployer)
  const  buinC = await  getDeployedContract(buin,GLDTokenABI,deployer2)
  
  const  InterestsC = await  getDeployedContract(contractAddress.Interests,InterestsABI,deployer2)

  // let tx = await usdtC.approve(valut.address,"1000000000000000000000000000000")
  // console.log("授权成功:",tx.hash)
  
  let tx2 = await buinC.approve(valut.address,"1000000000000000000000000000000")
  console.log("授权成功:",tx2.hash)
  
  // const de4 = await valut.deposit(usdt,"1000000000000000000000000",{value:"90000105168006011"})
  // console.log("存款token成功:",de4.hash);
  
  const dusdc = await valut2.deposit(buin,"100000000000000000000000",{value:"90000105168006011"})
  console.log("存款token成功:",dusdc.hash)

  // // const de422= await valut2.depositETH(100000000,{value:"90000105168006011"})
  // // console.log("eth充值成功:",de422.hash)
 
  //console.log(await valut.withdrawTest("1",usdt));
}

main();


//没有上传小结算前
