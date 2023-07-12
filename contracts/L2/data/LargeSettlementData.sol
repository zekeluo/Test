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

    uint256 constant public precision = 100000;

    struct Data{
        address user; 
        bytes32 capitaMerkleRoot; 
        address [] coinList; 
        uint256 [] withdrawnValues;
        uint8 checkOutType; // 1 提币 2 利息
        bytes32  messageHash; 
        bytes signature;
    }

    uint16 public dstChainId;

    address public smallSettlement; // 小结算合约地址 

    address public interests;

    bytes public adapterParams;

    mapping(address => mapping(address => uint256)) internal _deAmountL1;

    uint256 public totalValue;

    address  public usdt;

      //时间差
    uint256 public withdrawalTime; // 60 * 60 * 24 * 7

    uint256 public lastSmallsettlement;

    uint256 public apy;

    uint256 public totalPrincipal; // USDT的总本金
    uint256 public totalValueBefore;
    uint256 public totalPrincipalBefore;
}