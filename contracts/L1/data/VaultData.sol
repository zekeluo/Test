//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultData {

    enum OperateType{
        NONE,
        DEPOSIT, // 充值
        DEPOSITETH, // 充值ETH
        WITHDRAW, // 提现
        WITHDRAWINTEREST // 提利息
    }
    
    bytes32 public constant OWENER_ROLE = keccak256("OWENER_ROLE");
    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");
    bytes32 public constant FEE_ROLE = keccak256("FEE_ROLE");

    uint16 public dstChainId;
    address public interest;
    address public aave;
    bytes public adapterParams;
   
    struct Account {
      address user;
      bytes32 capitalMerkleRoot;
      mapping(address => uint256) capitalBalance;
      uint256 capitalNonce;
      bytes32 tradingMerkleRoot;
      mapping(address => uint256) tradingBalance;
      uint256 tradingNonce;
      uint nativeFee;
    }

   mapping(address => Account) public accounts;
   
   mapping(address => bool) public isSupDe;
   
   mapping(address => uint256)private latestShare;
   
   bool public isOpen;

   struct InData{
        address user; 
        bytes32 capitalMerkleRoot; 
        address [] coinList; 
        uint256 [] withdrawnValues;
        uint256 nativeFee;
        uint8 checkOutType; // 1 提币 2 利息
        bytes32 messageHash; 
        bytes signature;
    }

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) public _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    address[] coinList;

    mapping(address => bool) public isTrueForCoin;
    
    address public usdt;
}
