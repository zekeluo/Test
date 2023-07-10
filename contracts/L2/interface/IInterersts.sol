//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInterersts{

    function update_deposit(uint256 amount_, address user_) external;

    function update_withdraw(uint256 amount_, address user_) external;

    function shareTransfer(address user_,uint256 amount_,bool isProfit_,address coinType_) external;

    function getBalanceWithInterest(address user_) external view returns (uint256);
    
    function withdrawInterest(address user_) external returns(uint256);

    function totalShares() external view returns(uint256);

    function shares(address user) external view returns(uint256);
}
