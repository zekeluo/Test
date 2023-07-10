//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISmallSettlement{

    function hasRole(bytes32 role, address account) external view returns(bool);

    function verifyEcrecover(bytes32 messageHash, bytes memory signature) external pure returns(address);

    function coinListLength() external view returns(uint256);

    function getCoinList() external view returns(address[] memory);

    function coinList(uint256 index) external view returns(address);

    function getAccount(address user,address coinType) external view returns(address,bytes32,bytes32,uint256,uint256,uint256);

    function isOpen() external view returns(bool);
    
    function setAccount(address user_,address coinAdd_,uint256 amount_,uint256 amount2_, bool re_) external;
 
    function getCoinFeeAdd() external view returns (address[] memory);

     function getTotalFee(address add_)external view returns(uint256);

    function coinFeeMa(address add_)external view returns(bool);

    function setTotalFee(address) external;
    
    event eventVerificationBook();
    event eventSetwhiteLlist(address whiteAddress_);
    event evenTransferOfFunds(address user_, address[] coinType_, uint256[] balance);
    event eventWithholding(address[] addList, uint256[] amount, bool coinType, address user);
    event eventVerificationBookFoTrade();
}
