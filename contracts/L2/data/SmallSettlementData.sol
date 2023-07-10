//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SmallSettlementData{

    bytes32 public constant OWENER_ROLE = keccak256("OWENER_ROLE");
    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    struct Account {
        address user;
        bytes32 capitalMerkleRoot;
        mapping(address => uint256) capitalBalance;
        uint256 capitalNonce;
        bytes32 tradingMerkleRoot;
        mapping(address => uint256) tradingBalance;
        uint256 tradingNonce;
    }

    struct WithholdingData {
        address[] addList;
        uint256[] amount;
        bool coinType;
        address user;
        bytes32 messageHashUser;
        bytes signatureUser;
        bytes32 messageHashNode;
        bytes signatureNode;  
    }

    struct OutData{
        address user; 
        bytes32 capitaMerkleRoot; 
        uint256 totalShares; 
        uint256 shares; 
        uint nativeFee; 
    }
   
    bool _isOpen;

    address[]  public _coinList;

    address public largeSettlement; // 大结算合约地址

    address public interests;

    mapping(bytes32 => RoleData) public _roles;

    //映射用户的授权对象
    mapping(address => mapping(address => bool)) public auobject;

    mapping(address => Account) public accounts;

    mapping(address => mapping(address =>uint256)) public budgeCa;

    mapping(address => mapping(address =>uint256)) public budgetrd;

    mapping(address =>  bytes32[]) public capitaMRoot;

    mapping(address =>  bytes32[]) public tradingMRoot;

    mapping(address => mapping(address => uint256)) public deAmountL2;

    mapping(address => bool) public isSupDe;

    mapping(address => bool) public isTrueForCoin;

    mapping(string => bool) public ids;

    struct TradeBill {
        string id;
        address user;  
        uint256 goodsAmount;
        address goodsAddress;
        bool isNegativeforGoods;
        uint256 coinAmount;
        address coinAddress;
        bool isNegativeforCoin;
        uint256 fee;
        address feeCoin;
        uint256 nonce;
        bytes32 messageHash;
        bytes signature;
    }
    
    //验证订单是否匹配
    //数量匹配：确保买单的数量等于卖单的数量，或者买单的数量可以完全匹配卖单。
    //taker coinAmount ==  maker goodsAmount
    //taker goodsAmount == coinAmount  
    struct TradeBills{
        TradeBill[] bill;
    }
    
    struct Bill {
        string id;
        address user;
        uint256 [] balance;
        address [] coinType;
        bool    actionType; // 0操作交易      1资金
        uint256 coinAmount;
        address coinAddress;
        bool isNegative;
        bool isNegativeforTransfer; // true -  false +
        uint256 nonce;//  capitalNonce
        uint16 orderType; //(1充值,2提现,3划转)
        bytes32 messageHash;
        bytes signature;
    }

    address[]  public   coinFeeAdd;

    mapping (address  => uint256)  public   totalFee;
    
}

