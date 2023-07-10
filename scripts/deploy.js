const fs = require('fs');
const VaultABI = require('../package/abi/Vault.json');
const SmallSettlementABI = require('../package/abi/SmallSettlement.json');
const LargeSettlementABI = require('../package/abi/LargeSettlement.json');
const InterestsABI = require('../package/abi/Interests.json');

const {getDeployer,deployNewFromAbi} = require("./help");
const {DEPLOYER_PRIVATE_KEY,FROM_RPC_ENDPOINT,TO_RPC_ENDPOINT,lendingPool_,L1_ENDPOINTS,L2_ENDPOINTS,L1_dstChainId,L2_dstChainId,usdt,withdrawalTime} = process.env;

async function main(){
   let address_= {};

   const deployer = getDeployer(FROM_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);
   const valut = await hre.ethers.getContractFactory("Vault");
   const valutC = await deployNewFromAbi(VaultABI, valut.bytecode, deployer, [lendingPool_,L1_ENDPOINTS,L2_dstChainId,usdt])
   await valutC.deployed();
   address_.valut = valutC.address
   console.log("L1 deployed:",valutC.address);
 
   const deployerTO = getDeployer(TO_RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

   const SmallSettlement = await ethers.getContractFactory("SmallSettlement");
   const SmallSettlementC  = await deployNewFromAbi(SmallSettlementABI,SmallSettlement.bytecode,deployerTO,[]);
   console.log("L2 SmallSettlement deployed:",SmallSettlementC.address);
   address_.SmallSettlement = SmallSettlementC.address;
   fs.writeFileSync("contractAddress.json",JSON.stringify(address_));

   const LargeSettlement = await ethers.getContractFactory("LargeSettlement");
   const LargeSettlementC  = await deployNewFromAbi(LargeSettlementABI,LargeSettlement.bytecode,deployerTO,[L2_ENDPOINTS,L1_dstChainId, SmallSettlementC.address,withdrawalTime,usdt]);
   console.log("L2 LargeSettlement deployed:",LargeSettlementC.address);
   address_.LargeSettlement = LargeSettlementC.address;
   fs.writeFileSync("contractAddress.json",JSON.stringify(address_));

   const Interests = await hre.ethers.getContractFactory("Interests");
   const InterestsC  = await deployNewFromAbi(InterestsABI,Interests.bytecode,deployerTO,[valutC.address,lendingPool_]);
   console.log("L1 Interests deployed:",InterestsC.address);
   address_.Interests = InterestsC.address
   fs.writeFileSync("contractAddress.json",JSON.stringify(address_));

   // concat remote and local address
   let remoteAndLocal = hre.ethers.utils.solidityPack(
      ['address','address'],
      [LargeSettlementC.address, valutC.address]
  )

  // check if pathway is already set
  const isTrustedRemoteSet = await valutC.isTrustedRemote(10143, remoteAndLocal);

  if(!isTrustedRemoteSet) {
      try {
          let tx = await (await valutC.setTrustedRemote(10143, remoteAndLocal)).wait()
           console.log("From设置远程地址:");
      }catch{

      }
   }

   // concat remote and local address
   let remoteAndLocal2 = hre.ethers.utils.solidityPack(
      ['address','address'],
      [valutC.address, LargeSettlementC.address]
  )

  // check if pathway is already set
  const isTrustedRemoteSet2 = await LargeSettlementC.isTrustedRemote(10121, remoteAndLocal2);

  if(!isTrustedRemoteSet2) {
      try {
          let tx = await (await LargeSettlementC.setTrustedRemote(10121, remoteAndLocal2)).wait()
          console.log("TO设置远程地址:");
      }catch{
         
      }
   }
   
   let account = await hre.ethers.getSigners();

   await valutC.setSupDe(usdt,true);
   await valutC.setAdapterParams(1,1000000);
   await valutC.setWhilLlist("0xA2819587246aa449569B8086D1687e8a474665aD",1);
   await valutC.setWhilLlist("0x0A64Bc73793FAf399Adb51EBAd204Acb11F0ae64",1);
   await valutC.setWhilLlist("0x0A64Bc73793FAf399Adb51EBAd204Acb11F0ae64",2);
   const coinList = ['0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984', 
   '0x1c4dfef77001e2928e4fd0d758f89d37e10e8b79', '0x68b4a1c180f89818d4b90a51875299716a94c753','0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7'];  
   await valutC.setDeCoinList(coinList,true)

   await SmallSettlementC.setLargeSettlement(LargeSettlementC.address); // 设置大结算的合约地址
   await SmallSettlementC.setWhilLlist(account[0].address);
   await SmallSettlementC.setWhilLlist("0xAC5BF21516f6D1Cc780fDA152927548dDB7A5Fe2");
   await SmallSettlementC.setWhilLlist("0xF228eF12df79fdcAd80ee015F2123995ADe84ada");
   await SmallSettlementC.setWhilLlist("0xA2819587246aa449569B8086D1687e8a474665aD");
   await SmallSettlementC.setWhilLlist(deployer.address);
   await SmallSettlementC.setSupDe(usdt,true);

   await LargeSettlementC.setInterests(InterestsC.address);
   await LargeSettlementC.setAdapterParams(1,1000000);
   await LargeSettlementC.setApy(5);
   
   await InterestsC.setLargeSettlement(LargeSettlementC.address);
   await InterestsC.setSmallSettlement(SmallSettlementC.address);
 
   await SmallSettlementC.setInterests(InterestsC.address); 
   console.log("Done------------");
 
}
main();

