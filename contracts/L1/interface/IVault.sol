//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault {
    function deposit(address type_, uint256 amount_)payable external;

    function depositETH(uint256 amount_) payable external;
    
    function withdraw(uint256 [] memory amount_,address [] memory coin_) external;

    event eventWithdraw(address[]type_, uint256 [] amount_,address sender_);

    event eventDepositETH(uint256 amount_,address sender_);

    event eventDeposit(address type_,uint256 amount_,address sender_);

    event eventCheckOutInterest (address user_,address coin_,uint256 interest_);

    event eventReceive(address user ,address[] coinAdd_, uint256[] capitalValues_, uint8 checkOutType);

    event eventReceiveInterest(address user ,address coinAdd_, uint256 capitalValues_, uint8 checkOutType);

    event eventWithdrawInterest(address user, address coinType, uint256 interestBalance);

    event eventSetWhilLlist(address user_,bool re_ );

    event eventWithdrawFee(address user, address coin, uint256 amount);
}
