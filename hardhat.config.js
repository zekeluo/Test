require('hardhat-gas-reporter');
require('hardhat-deploy');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-abi-exporter');
require("@nomiclabs/hardhat-etherscan");
require('hardhat-deploy-ethers');
const dotenv = require('dotenv');
dotenv.config()
const {CHAIN_NAME,DEPLOYER_PRIVATE_KEY,FROM_RPC_ENDPOINT,DEPLOYER_PRIVATE_KEY2} = process.env;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

module.exports = {
	// defaultNetwork: hardhat,
	networks: {  
		hardhat:{
		},
		localhost:{
			url:"http://127.0.0.1:8545/",
			accounts: [DEPLOYER_PRIVATE_KEY]
		},
		 main: {
		  url: FROM_RPC_ENDPOINT,
		  accounts: [DEPLOYER_PRIVATE_KEY,DEPLOYER_PRIVATE_KEY2]
		},
		goerli:{
			url:FROM_RPC_ENDPOINT,
			accounts: [DEPLOYER_PRIVATE_KEY,DEPLOYER_PRIVATE_KEY2]
		}
	  },

	solidity: {
	    compilers: [
			{
				version: '0.8.0',
				settings: {
				  optimizer: { enabled: true, runs: 1 },
				  evmVersion: 'istanbul',
				}
			  },
			  {
				version: '0.6.12',
				settings: {

				  optimizer: { enabled: true, runs: 1 },
				  evmVersion: 'istanbul',
				}
			  },
		  {
			version: '0.8.2',
			settings: {
        	optimizer: { enabled: true, runs: 1 },
			  evmVersion: 'istanbul',
			}
		  },
		  {
			version: '0.8.17',
			settings: {
			  optimizer: { enabled: true, runs: 1 },
			  evmVersion: 'istanbul',
			}
		  },
	    ],
	  },abiExporter: { 
		path : `./package/abi` , 
		runOnCompile : true , 
		clear : true , 
		flat : true , 
		only : ['SmallSettlement','LargeSettlement','Vault','Erc20',"Interests","test"] ,
		间距: 2 , 
		format : "json" ,  
	  },
	  etherscan: {
		apiKey: "C5PCM9Y8E9CVRK47CI5Q79X59GV375DVYX"
	  }
};
