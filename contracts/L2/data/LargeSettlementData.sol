//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LargeSettlementData{

    enum OperateType{
        NONE,
        DEPOSIT, // 充值
        DEPOSITETH, // 充值ETH
        WITHDRAW, // 提现
        WITHDRAWINTEREST // 提利息
    }

    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");

    struct Data{
        address user; 
        bytes32 capitaMerkleRoot; 
        address [] coinList; 
        uint256 [] withdrawnValues;
        uint256 nativeFee;
        uint8 checkOutType; // 1 提币 2 利息
        bytes32  messageHash; 
        bytes signature;
    }

    uint16 public dstChainId;

    address public smallSettlement; // 小结算合约地址 

    address public interests;

    bytes public adapterParams;

    mapping(address => mapping(address => uint256)) _deAmountL1;

    uint256 public totalValue;

    address  public usdt;

      //时间差
    uint256 public withdrawalTime; // 60 * 60 * 24 * 7

    uint256 public lastSmallsettlement;

    uint256 public apy;


}