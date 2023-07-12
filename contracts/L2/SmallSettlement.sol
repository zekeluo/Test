//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interface/ILargeSettlement.sol";
import "./interface/ISmallSettlement.sol";
import "./interface/IInterersts.sol";
import "./data/SmallSettlementData.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SmallSettlement is Ownable2Step, SmallSettlementData, ISmallSettlement, ReentrancyGuard{

    mapping(address => bool)public  override  coinFeeMa;
    
    modifier onlyNode(){
        require(
            hasRole(NODE_ROLE, msg.sender), "Only node can call this.");
        _;
    }

    constructor(){
        _setupRole(OWENER_ROLE, msg.sender);
        _isOpen = true;
    }

    function hasRole(bytes32 role, address account) public view override returns(bool){
        return _roles[role].members[account];
    }

    function _setupRole(bytes32 role, address account) internal{
        _grantRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal{
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
        }
    }

    //用户划转预扣
    function withholding(WithholdingData memory data_) public nonReentrant{
        // 校验用户hash
        require(keccak256(abi.encodePacked(data_.addList, data_.amount, data_.coinType, data_.user)) == data_.messageHashUser, "withholding: user hash is error");
        // 校验节点hash
        require(keccak256(abi.encodePacked(data_.addList, data_.amount, data_.coinType, data_.user)) == data_.messageHashNode, "withholding: node hash is error");
        //req用户和节点签名
        require(auobject[data_.user][verifyEcrecover(data_.messageHashUser,
        data_.signatureUser)]||verifyEcrecover(data_.messageHashUser,
        data_.signatureUser) == data_.user ,"The signer is not user");

        require(hasRole(NODE_ROLE, verifyEcrecover(data_.messageHashNode,
        data_.signatureNode)),"The signer is not a node");

        Account storage account = accounts[data_.user];
        for(uint256 i =0; i< data_.addList.length; i++){
            if(data_.coinType){
                // 1 资金 => 交易，预扣交易账户 + 此次划转额度 <= 资金账户余额
                require(budgetrd[data_.user][data_.addList[i]] + data_.amount[i] <= account.capitalBalance[data_.addList[i]], "withholding: Insufficient withholding of capital account");
                 budgetrd[data_.user][data_.addList[i]] += data_.amount[i];
            }else{
                // 0 交易 => 资金，预扣资金账户 + 此次划转额度 <= 交易账户余额
                require(budgeCa[data_.user][data_.addList[i]] + data_.amount[i] <= account.tradingBalance[data_.addList[i]], "withholding: Insufficient withholding of trade account");
                budgeCa[data_.user][data_.addList[i]] += data_.amount[i];
            }
        }
        emit eventWithholding(data_.addList, data_.amount, data_.coinType, data_.user);
    }

    //根据签名方式分
    //1.充值,划转(1.资金账户  2.交易账户),提币(A)
    function verifySignatureA(Bill memory  bill_) view internal{
        require(keccak256(abi.encodePacked(bill_.id, bill_.user, bill_.balance, bill_.coinType, bill_.actionType, bill_.coinAmount, bill_.coinAddress, bill_.isNegative, bill_.isNegativeforTransfer, bill_.orderType)) == bill_.messageHash, "verifySignatureA: hash is error");
        require(hasRole(NODE_ROLE, verifyEcrecover(bill_.messageHash,
        bill_.signature)),"The signer is not a node");
    }
    
    //(划转)
    function transferOfFunds(Bill memory bill_) private{
       bytes32 root;
       require(_isOpen == true,"closing");
       Account storage account = accounts[bill_.user];
       require(bill_.balance.length == bill_.coinType.length,"Length faild");
       bytes32 [] memory capitaMroots_ = capitaMRoot[bill_.user];
       bytes32 [] memory tradingroots_ = tradingMRoot[bill_.user];
       for(uint256 i = 0; i<bill_.balance.length; i++){
            if(bill_.actionType){
                if(bill_.isNegativeforTransfer){
                    // 资金 => 交易, 交易预扣账户 >= 此次小结算订单balance
                    require(budgetrd[bill_.user][bill_.coinType[i]] >= bill_.balance[i],"transferOfFunds: Insufficient withholding of trade account");
                    // 资金账户 >= 此次小结算订单balance
                    require(account.capitalBalance[bill_.coinType[i]] >= bill_.balance[i],"transferOfFunds: Insufficient capital account");
                    budgetrd[bill_.user][bill_.coinType[i]] -= bill_.balance[i];
                    account.capitalBalance[bill_.coinType[i]] -= bill_.balance[i];
                }else{
                    account.capitalBalance[bill_.coinType[i]] += bill_.balance[i];
                }
            }else{
                if(bill_.isNegativeforTransfer){
                    // 交易 => 资金, 资金预扣账户 >= 此次小结算订单balance
                    require(budgeCa[bill_.user][bill_.coinType[i]] >= bill_.balance[i],"transferOfFunds: Insufficient withholding of capital account");
                    // 交易账户 >= 此次小结算订单balance
                    require(account.tradingBalance[bill_.coinType[i]] >= bill_.balance[i],"transferOfFunds: Insufficient trade account");
                    budgeCa[bill_.user][bill_.coinType[i]] -= bill_.balance[i];
                    account.tradingBalance[bill_.coinType[i]] -= bill_.balance[i];
                }else{
                    account.tradingBalance[bill_.coinType[i]] += bill_.balance[i];
                }
            }
        }
        if(bill_.actionType){
            require(bill_.nonce == account.capitalNonce + 1, "capital nonce failed");
            if(capitaMroots_.length != 0){
                root = _buildMerkleTree(capitaMroots_[capitaMroots_.length - 1], bill_.messageHash);
            }else{
                root = _buildMerkleTree(bill_.messageHash, bill_.messageHash);
            }
            capitaMRoot[bill_.user].push(root);
            account.capitalNonce = bill_.nonce;
            account.capitalMerkleRoot = root;
        }else{
            require(bill_.nonce == account.tradingNonce + 1, "trading nonce failed");
            if(tradingroots_.length != 0){
                root = _buildMerkleTree(tradingroots_[tradingroots_.length - 1],bill_.messageHash);
            }else{
                root = _buildMerkleTree(bill_.messageHash, bill_.messageHash);
            }
            tradingMRoot[bill_.user].push(root);
            account.tradingNonce = bill_.nonce;    
            account.tradingMerkleRoot = root;
        }
    }

    //(1充值,2提现,3划转)
    function verificationBook(Bill[] memory  bill_) external onlyNode nonReentrant{
           require(ILargeSettlement(largeSettlement).timeLock()== false, "Lock has been closed");
           ILargeSettlement(largeSettlement).setLastSmallsettlement();
        for(uint256 i = 0; i <bill_.length; i++){
            require(!ids[bill_[i].id], "verificationBook: id already exists");
            ids[bill_[i].id] = true;
            if(bill_[i].orderType == 1 || bill_[i].orderType == 2){
                verifySignatureA(bill_[i]);
                _build(bill_[i]);
            }else if(bill_[i].orderType == 3){  //这样不会重复
                verifySignatureA(bill_[i]);
                transferOfFunds(bill_[i]);
            }
        }
        emit eventVerificationBook();
    }

     //(4.交易)
    function verificationBookFoTrade(TradeBills[] memory tradeBills) external onlyNode nonReentrant{
        require(tradeBills.length > 0, "tradeBills length is error");
        require(ILargeSettlement(largeSettlement).timeLock()== false, "Lock has been closed");
        ILargeSettlement(largeSettlement).setLastSmallsettlement();
        for(uint256 i=0; i<tradeBills.length; i++) {
            //验签
            verifySignatureB(tradeBills[i]);
            //建树
            _tradeBuild(tradeBills[i]);
        }
        emit eventVerificationBookFoTrade();
    }

    function verifySignatureB(TradeBills memory bill_) private view{
        // 0 买家 1 卖家
        require(bill_.bill[0].coinAddress == bill_.bill[1].coinAddress && bill_.bill[0].coinAmount == bill_.bill[1].coinAmount && bill_.bill[0].isNegativeforCoin == false && bill_.bill[1].isNegativeforCoin == true, "verifySignatureB: coin mismatch between buyer and seller");
        require(bill_.bill[0].goodsAddress == bill_.bill[1].goodsAddress && bill_.bill[0].goodsAmount == bill_.bill[1].goodsAmount && bill_.bill[0].isNegativeforGoods == true && bill_.bill[1].isNegativeforGoods == false, "verifySignatureB: goods mismatch between buyer and seller");
        require(bill_.bill[0].feeCoin == bill_.bill[0].goodsAddress && bill_.bill[1].feeCoin == bill_.bill[1].coinAddress, "verifySignatureB: fee mismatch between buyer and seller");
        for(uint256 i=0; i<2; i++) {
            TradeBill memory bill = bill_.bill[i];

            require(keccak256(abi.encodePacked(bill.id, bill.user, bill.goodsAmount, bill.goodsAddress, bill.isNegativeforGoods, bill.coinAmount, bill.coinAddress, bill.isNegativeforCoin, bill.fee, bill.feeCoin)) == bill.messageHash, "verifySignatureB: hash is error");

            require(auobject[bill.user][verifyEcrecover(bill.messageHash,
                bill.signature)]||verifyEcrecover(bill.messageHash,
                bill.signature) == bill.user ,"The signer is not user");
        }
    }

    //交易建树
    function _tradeBuild(TradeBills memory bs_) internal returns(bytes32,uint256,address,uint256,address) {  
        for(uint256 i=0; i<2; i++){
            require(!ids[bs_.bill[i].id], "_tradeBuild: id already exists");
            ids[bs_.bill[i].id] = true;
            bytes32 root;
            require (bs_.bill[i].nonce == accounts[bs_.bill[i].user].tradingNonce + 1, "trading nonce failed");
            if(tradingMRoot[bs_.bill[i].user].length != 0){
                bytes32 [] memory roots_ = tradingMRoot[bs_.bill[i].user];
                root = _buildMerkleTree(roots_[roots_.length-1],bs_.bill[i].messageHash);
            }else{
                root = _buildMerkleTree(bs_.bill[i].messageHash,bs_.bill[i].messageHash);
            }
            if(bs_.bill[i].isNegativeforGoods) {
                accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].goodsAddress] += bs_.bill[i].goodsAmount;
                 if(isSupDe[bs_.bill[i].goodsAddress]){
                    IInterersts(interests).shareTransfer(bs_.bill[i].user,bs_.bill[i].goodsAmount,true,bs_.bill[i].goodsAddress);
                     ILargeSettlement(largeSettlement).setTotalUsdt(bs_.bill[i].user, bs_.bill[i].goodsAmount,true); 
                }
            }else{
                require(accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].goodsAddress] >= bs_.bill[i].goodsAmount, "trading goods balance is negative");
                accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].goodsAddress] -= bs_.bill[i].goodsAmount;
                if(isSupDe[bs_.bill[i].goodsAddress]){
                    IInterersts(interests).shareTransfer(bs_.bill[i].user,bs_.bill[i].goodsAmount,false,bs_.bill[i].goodsAddress);
                    ILargeSettlement(largeSettlement).setTotalUsdt(bs_.bill[i].user, bs_.bill[i].goodsAmount,false); 
                }
            }

            if(bs_.bill[i].isNegativeforCoin) {
                accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].coinAddress] += bs_.bill[i].coinAmount;
                if(isSupDe[bs_.bill[i].coinAddress]){
                    IInterersts(interests).shareTransfer(bs_.bill[i].user,bs_.bill[i].coinAmount,true,bs_.bill[i].coinAddress);
                     ILargeSettlement(largeSettlement).setTotalUsdt(bs_.bill[i].user, bs_.bill[i].coinAmount,true); 
                }
             
            }else{
                require(accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].coinAddress] >= bs_.bill[i].coinAmount, "trading coin balance is negative");
                accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].coinAddress] -= bs_.bill[i].coinAmount;
                if(isSupDe[bs_.bill[i].coinAddress]){
                    IInterersts(interests).shareTransfer(bs_.bill[i].user,bs_.bill[i].coinAmount,false,bs_.bill[i].coinAddress);
                    ILargeSettlement(largeSettlement).setTotalUsdt(bs_.bill[i].user, bs_.bill[i].coinAmount,false); 
                }
              
            }

            //fee
            accounts[bs_.bill[i].user].tradingBalance[bs_.bill[i].feeCoin] -= bs_.bill[i].fee;
            addFee(bs_.bill[i].feeCoin,bs_.bill[i].fee);
            tradingMRoot[bs_.bill[i].user].push(root);
            accounts[bs_.bill[i].user].tradingNonce = bs_.bill[i].nonce;    
            accounts[bs_.bill[i].user].tradingMerkleRoot = root;
        }
     }

    //(充值,提币建树)
    function _build(Bill memory bs_) internal returns(bytes32,uint256,address,uint256,address) {
        bytes32 root;
        //资金账户
        Account storage account =  accounts[bs_.user];
        isCoinList(bs_.coinAddress,bs_.coinAddress);
        require (bs_.nonce == account.capitalNonce + 1,"capital nonce failed");
        //充值
        if(bs_.orderType == 1){
            //deAmountL1 deAmountL2 确保L2上传充值订单的数量,不能大于L1充值数量即可
            require(ILargeSettlement(largeSettlement).deAmountL1(bs_.user, bs_.coinAddress) >= deAmountL2[bs_.user][bs_.coinAddress]+bs_.coinAmount,"Deposit failure");
            deAmountL2[bs_.user][bs_.coinAddress] += bs_.coinAmount;
        }
        
        if(capitaMRoot[bs_.user].length != 0){
            bytes32 [] memory roots_ = capitaMRoot[bs_.user];
            root = _buildMerkleTree(roots_[roots_.length-1],bs_.messageHash);
        }else{
            root = _buildMerkleTree(bs_.messageHash,bs_.messageHash);
        }

        if(bs_.orderType !=2){

            if(bs_.isNegative) {
                account.capitalBalance[bs_.coinAddress] += bs_.coinAmount;
            }else{
                require(account.capitalBalance[bs_.coinAddress] >= bs_.coinAmount,"capital coin balance is negative");
                account.capitalBalance[bs_.coinAddress] -= bs_.coinAmount;
            }
        }
        
        capitaMRoot[bs_.user].push(root);
        account.capitalNonce = bs_.nonce;    
        account.capitalMerkleRoot = root;
    }

    function getData(address user_) external view returns(OutData memory) {
        (uint nativeFee,) = ILargeSettlement(largeSettlement).estimateFee(user_);
        return OutData(user_, accounts[user_].capitalMerkleRoot, nativeFee);
    }

    function getAccount(address address_,address type_) public view override returns(address,bytes32,bytes32,uint256,uint256,uint256){
        Account storage account = accounts[address_]; 
        return (address_, account.capitalMerkleRoot, account.tradingMerkleRoot, account.capitalBalance[type_], account.capitalNonce, account.tradingBalance[type_]);
    }

    function getNonce(address address_) public view returns (uint256,uint256) {
        Account  storage account = accounts[address_]; 
        return (account.capitalNonce, account.tradingNonce);
    }

    function isCoinList(address goodsAddress,address coinAddress) private{
        if(isTrueForCoin[goodsAddress] == false){
            isTrueForCoin[goodsAddress] = true;
            _coinList.push(goodsAddress);
        }
        if(isTrueForCoin[coinAddress] == false){
            isTrueForCoin[coinAddress] = true;
            _coinList.push(coinAddress);
        }
    }

    function coinListLength() external view override returns(uint256){
        return _coinList.length;
    }

    function getCoinList() external view override returns(address[] memory){
        return _coinList;
    }

    function coinList(uint256 index) external view override returns(address){
        return _coinList[index];
    }

    function isOpen() external view override returns(bool){
        return _isOpen;
    }

    function hashMessage(bytes32  message) public pure returns(bytes32 messageHash){
        messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return messageHash;
    }

    function verifyEcrecover(bytes32 messageHash,bytes memory signature) public pure override returns(address){
        bytes32 hash = hashMessage(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = recover(signature);
        return  ecrecover(hash, v, r, s);
    }

    function _buildMerkleTree(bytes32 left, bytes32 right) public pure returns (bytes32 ) {
        if(keccak256(abi.encodePacked(left)) == keccak256(abi.encodePacked(right)) ) {
            return keccak256(abi.encodePacked(left));
        }else{
            return keccak256(abi.encodePacked(left,right));
        }
    }

    function recover(bytes memory signature) internal pure returns (uint8, bytes32, bytes32) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return (v, r, s);
    }

    function setAuobject(address  user_,bool re_,address auObject_ ,bytes32  messageHas_,bytes  memory signature_) external{
        //验签规则
        require(keccak256(abi.encodePacked(user_, re_, auObject_)) == messageHas_, "setAuobject: user hash is error");
        require(verifyEcrecover(messageHas_, signature_) == user_, "setAuobject: no user signature");
        auobject[user_][auObject_] = re_;
    }

    function setWhilLlist(address  add) external onlyOwner{
        _setupRole(NODE_ROLE,add);
    }

    function setIsOpen(bool re_) public onlyOwner{
        _isOpen = re_;
    }

    function setInterests(address re_) external onlyOwner{
        interests = re_;
    }

    function setSupDe(address add_,bool re_) external onlyOwner{
        isSupDe[add_] = re_;
    }

    function setLargeSettlement(address largeSettlement_) external onlyOwner{
        largeSettlement = largeSettlement_;
    }

    function setAccount(address user_,address coinAdd_,uint256 amount_,uint256 amount2_,bool re_) external override{
        require(msg.sender == largeSettlement, "no largeSettlement");
         Account storage account = accounts[user_];
        if(re_){
            account.capitalBalance[coinAdd_] -= amount_;
            account.tradingBalance[coinAdd_] -= amount2_;
        }else{
            account.capitalBalance[coinAdd_] -= amount_;
        }
    
    }

    function addFee(address add_,uint256 fee_) private{
        if(!coinFeeMa[add_]){

            coinFeeAdd.push(add_);
            coinFeeMa[add_] = true;
        }
        totalFee[add_] = fee_;
    }

    function setTotalFee(address add_) external override{
      require(msg.sender == largeSettlement, "no largeSettlement");
       totalFee[add_] = 0 ;
    }


    function getCoinFeeAdd() external view override returns (address[] memory){
         return coinFeeAdd;
    }
     
    function getTotalFee(address add_)external  override view returns(uint256){
        return totalFee[add_];
    }
  

}
