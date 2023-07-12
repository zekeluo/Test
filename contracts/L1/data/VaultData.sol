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
    address public aave;
    bytes public adapterParams;
   
    struct Account {
      address user;
      mapping(address => uint256) capitalBalance;
    }

   mapping(address => Account) public accounts;
   
   mapping(address => bool) public isSupDe;
   
   bool public isOpen;

   struct InData{
        address user; 
        bytes32 capitalMerkleRoot; 
        address [] coinList; 
        uint256 [] withdrawnValues;
        uint8 checkOutType; // 1 提币 2 利息
        bytes32 messageHash; 
        bytes signature;
    }

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) internal _roles;

    address[] public coinList;

    mapping(address => bool) public isTrueForCoin;
    
    address public usdt;

    mapping(address => uint256 ) public interestAmount;
    mapping(address => bool) public deCoinList;
    mapping(address => uint256 ) public totalFee;
    uint256 public totalPrincipal;
}
