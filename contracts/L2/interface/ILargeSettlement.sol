//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../data/LargeSettlementData.sol";
interface ILargeSettlement{

    function estimateFee(address user) external view returns(uint nativeFee, uint zroFee);

    function deAmountL1(address user, address coinType) external view returns(uint256);

    function getTotalValue() external view  returns(uint256);
    
    function totalUsdt(address user_) external view  returns(uint256);

    function setTotalUsdt(address user_, uint256 amount_, bool isFlag_) external;
   
    function timeLock() external view returns(bool);

    function setLastSmallsettlement() external;

    function setWithdrawalTim(uint256 time_)external;

    event eventReceive(address, uint256, address, LargeSettlementData.OperateType);
    
    event eventCheckOut(uint256 checkOutType);
}