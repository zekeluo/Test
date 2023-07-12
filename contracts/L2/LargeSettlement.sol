//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interface/ISmallSettlement.sol";
import "./interface/ILargeSettlement.sol";
import "./interface/IInterersts.sol";
import "../LayerZero/NonblockingLzApp.sol";
import "./data/LargeSettlementData.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LargeSettlement is NonblockingLzApp, LargeSettlementData, ILargeSettlement, ReentrancyGuard{

    mapping(address => uint256) public override totalUsdt;
    bool public override timeLock;

    event DepostBefore(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event DepostAfter(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event WithdrawInterestBefore(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event WithdrawInterestAfter(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event WithdrawBefore(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event WithdrawAfter(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event CheckOutFeeBefore(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event CheckOutFeeAfter(uint256 totalValue, uint256 totalPrincipal, uint256 userPrincipal);
    event CheckOutFee(address user, address[] coins, uint256[] amounts);

    modifier onlyNode() { 
        require(
            ISmallSettlement(smallSettlement).hasRole(NODE_ROLE, msg.sender), "Only node can call this.");
        _;
    }

    constructor(address lzEndpoint_,uint16 dstChainId_, address _smallSettlement, uint256 withdrawalTime_,address usdt_) NonblockingLzApp(lzEndpoint_) {
        dstChainId = dstChainId_;
        smallSettlement = _smallSettlement;
        withdrawalTime = withdrawalTime_;
        usdt = usdt_;
    }

    function checkOutFee() external payable nonReentrant{
        //手续费
        address[] memory getCoinFeeAdd = ISmallSettlement(smallSettlement).getCoinFeeAdd();
        uint[] memory _amount = new uint[](getCoinFeeAdd.length); 
        //遍历数组
        for(uint256 i=0; i < getCoinFeeAdd.length; i++){
            _amount[i] = ISmallSettlement(smallSettlement).getTotalFee(getCoinFeeAdd[i]);
            if(getCoinFeeAdd[i]== usdt){
                emit CheckOutFeeBefore(totalValue, totalPrincipal, 0);
                totalValue -= _amount[i];
                emit CheckOutFeeAfter(totalValue, totalPrincipal, 0);
            }
            ISmallSettlement(smallSettlement).setTotalFee(getCoinFeeAdd[i]);
        }
        bytes memory encoded = abi.encode(3,getCoinFeeAdd,_amount);
        _sentToL1(dstChainId,encoded);

        emit CheckOutFee(msg.sender, getCoinFeeAdd, _amount);
    }

    function checkOut(address user_, Data memory data_,address usdt_) payable external onlyNode nonReentrant{
        require(ISmallSettlement(smallSettlement).hasRole(NODE_ROLE, ISmallSettlement(smallSettlement).verifyEcrecover(data_.messageHash,data_.signature)),"The signer is not a node");
        require(keccak256(abi.encodePacked(data_.user,data_.capitaMerkleRoot,data_.coinList,data_.withdrawnValues, data_.checkOutType)) == data_.messageHash ,"Incorrect data");
        require(ISmallSettlement(smallSettlement).isOpen() == true,"Closing");
        bytes memory encoded ;
        //提币
        if(data_.checkOutType == 1){
            for(uint256 i=0; i<data_.coinList.length;i++){
                (, , , uint256 capitalBalance, , ) = ISmallSettlement(smallSettlement).getAccount(user_, data_.coinList[i]);
                require(capitalBalance >= data_.withdrawnValues[i],"Not sufficient funds");
                if(data_.coinList[i] == usdt){
                    emit WithdrawBefore(totalValue, totalPrincipal, totalUsdt[user_]);
                    IInterersts(interests).update_withdraw(data_.withdrawnValues[i], user_);
                    // 先算利息，再更新totalValue
                    totalPrincipalBefore = totalPrincipal;
                    totalValueBefore = totalValue;
                    totalValue -= data_.withdrawnValues[i];
                    totalUsdt[user_] -= data_.withdrawnValues[i];
                    totalPrincipal -= data_.withdrawnValues[i];
                    emit WithdrawAfter(totalValue, totalPrincipal, totalUsdt[user_]);
                }
                ISmallSettlement(smallSettlement).setAccount(user_,data_.coinList[i],data_.withdrawnValues[i],0,false);
            }
            encoded = abi.encode(1,data_);
        //提利息
        }else{
            if(totalValue > totalPrincipal){
               if(totalValueBefore - totalPrincipalBefore == 0){
                    // (totalValue - 充值总本金) / 充值总本金 <= 配置的利率
                    require((totalValue - totalPrincipal) * precision / totalPrincipal <= apy, "totalvalue exceptional_0");
                }else{
                    // 上一次的利息如果大于本次利息，直接过
                    if((totalValue - totalPrincipal) >= (totalValueBefore - totalPrincipalBefore)){
                    // [本次总利息(本次 totalValue - 本次totalPrincipal ) - 上次总利息(上次 totalValue - 上次totalPrincipal )] /  上次总利息(上次 totalValue - 上次totalPrincipal ) ≤ 配置的利率
                    require(((totalValue - totalPrincipal) - (totalValueBefore - totalPrincipalBefore)) * precision / (totalValueBefore - totalPrincipalBefore) <= apy, "totalvalue exceptional__");
                    }
                }
            }
            emit WithdrawInterestBefore(totalValue, totalPrincipal, totalUsdt[user_]);
            uint256 interestBalance = IInterersts(interests).withdrawInterest(user_);
            totalValueBefore = totalValue;
            totalValue -= interestBalance;
            emit WithdrawInterestAfter(totalValue, totalPrincipal, totalUsdt[user_]);

            encoded = abi.encode(2,interestBalance,user_);
        }

        _sentToL1(dstChainId,encoded);
        emit eventCheckOut(data_.checkOutType);
    }


    function checkOutForUser() external payable nonReentrant{
        uint256 capitalBalance;
        uint256 trdingBalance;

       require(block.timestamp - lastSmallsettlement >= withdrawalTime, "Time is not up");
        address[] memory coinList = ISmallSettlement(smallSettlement).getCoinList();
        uint256[] memory amount = new uint256[](coinList.length);
    
        uint256 interestBalance = IInterersts(interests).withdrawInterest(msg.sender);
        totalValue -= interestBalance;

        address[] memory getCoinFeeAdd = ISmallSettlement(smallSettlement).getCoinFeeAdd();
        uint[] memory _amount = new uint[](getCoinFeeAdd.length); 
    
        for(uint256 i=0; i < getCoinFeeAdd.length; i++){
            _amount[i] = ISmallSettlement(smallSettlement).getTotalFee(getCoinFeeAdd[i]);

            if(getCoinFeeAdd[i]== usdt){
                totalValue -= ISmallSettlement(smallSettlement).getTotalFee(usdt);
            }

            ISmallSettlement(smallSettlement).setTotalFee(getCoinFeeAdd[i]);
        }

        for(uint256 i=0; i<coinList.length;i++){
            //把资金账户的钱还有交易账户的钱都大结算.
            (, , ,  capitalBalance, , trdingBalance) = ISmallSettlement(smallSettlement).getAccount(msg.sender, coinList[i]);
            // 清空资金账户的钱,还有交易账户 
            ISmallSettlement(smallSettlement).setAccount(msg.sender,coinList[i],capitalBalance,trdingBalance,true);
            amount[i] = capitalBalance + trdingBalance;

            if(coinList[i] == usdt){
                IInterersts(interests).update_withdraw(capitalBalance + trdingBalance, msg.sender);
                // 先算利息，再更新totalValue
                totalValue -= capitalBalance + trdingBalance;
                totalUsdt[msg.sender] -= capitalBalance + trdingBalance;
          
            }
        }

        bytes memory encoded = abi.encode(4,msg.sender,coinList, amount, interestBalance);
        _sentToL1(dstChainId,encoded);
        timeLock = true;
    }

    function _sentToL1(uint16 _dstChainId,bytes memory _data) private{
        _lzSend(_dstChainId, _data, payable(msg.sender), address(0x0), adapterParams, msg.value);
    }

    function getOracle(uint16 remoteChainId) external view returns(address _oracle) {
        bytes memory bytesOracle = lzEndpoint.getConfig(lzEndpoint.getSendVersion(address(this)), 
        remoteChainId, address(this), 6);
        assembly {
            _oracle := mload(add(bytesOracle, 32))
        }
    }

    function getSize(address user_) public view returns(bytes memory){
        address[] memory getCoinFeeAdd = ISmallSettlement(smallSettlement).getCoinFeeAdd();

        uint[] memory _amount = new uint[](getCoinFeeAdd.length); 

        //遍历数组
        for(uint256 i=0; i < getCoinFeeAdd.length; i++){
            _amount[i] = ISmallSettlement(smallSettlement).getTotalFee(getCoinFeeAdd[i]);
        }

        return abi.encode(user_, ISmallSettlement(smallSettlement).getCoinList(), IInterersts(interests).totalShares(), IInterersts(interests).shares(user_),1, getCoinFeeAdd,_amount);
    }

    function estimateFee(address user) public view override returns(uint nativeFee, uint zroFee){
        return lzEndpoint.estimateFees(dstChainId, address(this),getSize(user), false, adapterParams);
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64 nonce, bytes memory encoded_) internal override {
        (address user_,address coinType_,uint256 balance,bool isSup, OperateType operateType,uint256 interestBalance)  = abi.decode(encoded_,(address,address,uint256,bool,OperateType,uint256));
        // 在充值时候，更新userShare、totalShare、totalValue, 提币是预扣,所以在这里不用
        emit DepostBefore(totalValue, totalPrincipal, totalUsdt[user_]);
        if(isSup){
            if(operateType == OperateType.DEPOSIT){
                IInterersts(interests).update_deposit(balance, user_);
                totalUsdt[user_] += balance;
                // usdt的总本金，用于利息测试  
                totalPrincipalBefore = totalPrincipal;
                totalPrincipal += balance;
            }
        }
        if(operateType == OperateType.DEPOSIT || operateType == OperateType.DEPOSITETH){
            _deAmountL1[user_][coinType_] += balance;
        }
        
        // 充值、提现都更新totalValue
        totalValueBefore = totalValue;
        totalValue  = totalPrincipal + interestBalance;
        emit DepostAfter(totalValue, totalPrincipal, totalUsdt[user_]);
        emit eventReceive(coinType_,balance,user_, operateType);
    }

    function setOracle(uint16 dstChainId, address oracle) external onlyOwner{
        uint TYPE_ORACLE = 6;
        // set the Oracle
        lzEndpoint.setConfig(lzEndpoint.getSendVersion(address(this)), dstChainId, TYPE_ORACLE, abi.encode(oracle));
    }

    function setAdapterParams(uint16 version,uint  gasForDestinationLzReceive) public onlyOwner{
        adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
    }

    function setSmallSettlement(address _smallSettlement) external onlyOwner{
        smallSettlement = _smallSettlement;
    }

    function setInterests(address _interests) external onlyOwner{
        interests = _interests;
    }

    function deAmountL1(address user, address coinType) external view override returns(uint256){
        return _deAmountL1[user][coinType];
    }

    function getTotalValue() external view override returns(uint256){
        return totalValue;
    }

    function setTotalUsdt(address user_,uint256 amount_,bool re_) public override{
        require(msg.sender == smallSettlement, "no smallSettlement");
        if(re_){
            totalUsdt[user_] +=amount_;
        }else{
            totalUsdt[user_] -=amount_;
        }
    }

    function setApy(uint256 _apy) external onlyOwner{
        apy = _apy * precision;
    }

    function setWithdrawalTim(uint256 time_)external override onlyOwner{
          withdrawalTime = time_;
    }

    function setLastSmallsettlement()external override{
          require(msg.sender == smallSettlement, "no smallSettlement");
          lastSmallsettlement = block.timestamp;
    }
    
}

