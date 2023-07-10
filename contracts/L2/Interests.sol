// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interface/ISmallSettlement.sol";
import "./interface/ILargeSettlement.sol";
import "./interface/IInterersts.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "hardhat/console.sol";
contract Interests is Ownable2Step, IInterersts{

    uint256 public override totalShares; // 总股数
    uint256 public currentPrice = 1; // 每股价值 (实时更新)
    address public smallSettlement;
    address public largeSettlement;

    mapping (address => uint256) public override shares; // 用户股数

    uint256 constant precision = 100000;

    event UpdateDepositBefore(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue);
    event UpdateDepositAfter(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue);
    event UpdateWithdrawBefore(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue);
    event UpdateWithdrawAfter(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue);
    event WithdrawInterestBefore(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue);
    event WithdrawInterestAfter(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue);
    event ShareTransferBefore(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue, bool isProfit_, address coinType_);
    event ShareTransferAfter(address user, uint256 amount, uint256 userShare, uint256 totalShares, uint256 totalValue, bool isProfit_, address coinType_);

    modifier onlyLargeSettlement() { 
        require(msg.sender == largeSettlement, "no largeSettlement");
        _;
    }

    modifier onlySmallSettlement() { 
        require(msg.sender == smallSettlement, "no smallSettlement");
        _;
    }

    constructor(address smallSettlement_, address largeSettlement_) {
        smallSettlement = smallSettlement_;
        largeSettlement = largeSettlement_;
    }

    //充值(充值之后,需要更新L2的总股数)
    function update_deposit(uint256 amount_, address user_) public override onlyLargeSettlement{

        emit UpdateDepositBefore(user_, amount_, shares[user_], totalShares, getBalanceWithInterest(user_));
        
        require(amount_ > 0, "Deposit amount must be greater than zero");
        // 每股价值= 总价值 / 总股数 (根据最新的总价值计算得出，第一次默认值为1)

        if(totalShares == 0 ){
            // Vault.sol 里的充值提现，应先更新本合约的股价值，再存取AAVE
            shares[user_] += amount_ * precision;
            totalShares = shares[user_];

        }else{
            
            //新股数和 = 总股数 + （充值金额 / 每股价值）（每股价值取充值前的最新股价） 
            uint256 newTotalShares = totalShares + (amount_ * totalShares / ILargeSettlement(largeSettlement).getTotalValue());
          
            //  用户新股数 = 充值数额 / 新的的每股价值
            shares[user_] += amount_ * totalShares / ILargeSettlement(largeSettlement).getTotalValue() ;
                             
            totalShares = newTotalShares;
            currentPrice = ILargeSettlement(largeSettlement).getTotalValue() / totalShares;
        }

        emit UpdateDepositAfter(user_, amount_, shares[user_], totalShares, getBalanceWithInterest(user_));
    }

    // 没用的变量可以去除
    //总价值变,总股数也变的情况(更新账本同步L2)
    function update_withdraw(uint256 amount_, address user_) public override onlyLargeSettlement{
        emit UpdateWithdrawBefore(user_, amount_, shares[user_], totalShares, getBalanceWithInterest(user_));
        if(amount_ !=0){
            uint256 oldTotalShare = totalShares;
            uint256 oldUserShare =  shares[user_];
            uint256 newUserShare;
            if(oldUserShare < amount_ * totalShares / ILargeSettlement(largeSettlement).getTotalValue()){
                newUserShare = 0;

            }else{
                newUserShare = oldUserShare - (amount_ * totalShares / ILargeSettlement(largeSettlement).getTotalValue());
  
            }
        
            uint256 newTotalShares = oldTotalShare - oldUserShare + newUserShare;
            totalShares = newTotalShares;
            shares[user_] = newUserShare;
        }
        emit UpdateWithdrawAfter(user_, amount_, shares[user_], totalShares, getBalanceWithInterest(user_));
    }

    // 计算用户当前余额和利息
    function getBalanceWithInterest(address user_) public view override returns(uint256){
        uint256 userSharesPrice;
        uint256 interestBalance;
     
        if(shares[user_] == 0){
            return 0;
        }else{ 
            userSharesPrice = shares[user_] * ILargeSettlement(largeSettlement).getTotalValue() / totalShares;  
        }
       
        if(userSharesPrice == 0 || userSharesPrice < ILargeSettlement(largeSettlement).totalUsdt(user_)){ 
            return 0;
        }
       
        interestBalance = userSharesPrice - ILargeSettlement(largeSettlement).totalUsdt(user_);
        return interestBalance;
    }
 
    function withdrawInterest(address user_) public override onlyLargeSettlement returns(uint256){
        emit WithdrawInterestBefore(user_, uint256(0), shares[user_], totalShares, ILargeSettlement(largeSettlement).getTotalValue());
        uint256 interestBalance = getBalanceWithInterest(user_);
      
        if(interestBalance > 0){

            shares[user_] -= interestBalance * totalShares / ILargeSettlement(largeSettlement).getTotalValue(); 
            totalShares -= interestBalance * totalShares / ILargeSettlement(largeSettlement).getTotalValue();

        }
        emit WithdrawInterestAfter(user_, interestBalance, shares[user_], totalShares, ILargeSettlement(largeSettlement).getTotalValue());
        return interestBalance;
      
    }

    function shareTransfer(address user_,uint256 amount_,bool isProfit_,address coinType_) public override onlySmallSettlement{
        emit ShareTransferBefore(user_, amount_, shares[user_], totalShares, ILargeSettlement(largeSettlement).getTotalValue(),  isProfit_, coinType_);

        uint256 userNewShare;
        require(ILargeSettlement(largeSettlement).getTotalValue() > 0, "TotalValue == 0");
        (, , , , , uint256 tradingBalance) = ISmallSettlement(smallSettlement).getAccount(user_, coinType_);
        uint256 userShareTotalPirce = shares[user_] * ILargeSettlement(largeSettlement).getTotalValue() / totalShares;

        if(isProfit_){
            userNewShare  = (userShareTotalPirce + amount_) * totalShares / ILargeSettlement(largeSettlement).getTotalValue();
        }else{
            // amount代表本金
            if(tradingBalance == amount_){
                // 充值500,因为假如有精度问题,股份价值只有499,那就直接将用户股份变成0
                if(userShareTotalPirce < amount_){
                    userNewShare = 0;
                }else{
                    // 用户当前股份 - amount / 当前每股价值
                    userNewShare = shares[user_] - amount_ * totalShares /  ILargeSettlement(largeSettlement).getTotalValue();
                }
            }else{
                userNewShare = (userShareTotalPirce - amount_) * totalShares / ILargeSettlement(largeSettlement).getTotalValue();
            }
        }
        shares[user_] = userNewShare;

        emit ShareTransferAfter(user_, amount_, shares[user_], totalShares, ILargeSettlement(largeSettlement).getTotalValue(),  isProfit_, coinType_);
    }

    function getPoolInfo(address user_)public view returns(uint256 userShare_, uint256 totalShare_,uint256 totalValue_){
        userShare_ =  shares[user_];
        totalShare_ = totalShares;
        totalValue_ = ILargeSettlement(largeSettlement).getTotalValue();
    }

    function setSmallSettlement(address _smallSettlement) external onlyOwner{
        smallSettlement = _smallSettlement;
    }

    function setLargeSettlement(address largeSettlement_) external onlyOwner{
        largeSettlement = largeSettlement_;
    }

}

   