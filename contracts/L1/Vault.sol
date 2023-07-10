//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interface/IVault.sol";
import "./data/VaultData.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../LayerZero/NonblockingLzApp.sol";
import "../Aave/ILendingPool.sol";
import "../Aave/DataTypes.sol";
import "../Aave/IStableDebtToken.sol";
import "../Aave/IVariableDebtToken.sol";

contract Vault is IVault,VaultData,NonblockingLzApp{

    mapping(address => uint256 ) public interestAmount;
    mapping(address => bool) public deCoinList;
    mapping(address => uint256 ) public totalFee;
    mapping(address => bool) public whlieList;
    uint256 public totalPrincipal;

    constructor(address lendingPool_, address lzEndpoint_, uint16 dstChainId_,address usdt_)NonblockingLzApp(lzEndpoint_) {
       aave = lendingPool_;
       dstChainId =dstChainId_;
       isOpen = true;
       usdt =usdt_ ;
    }
    
    function deposit(address type_, uint256 amount_) payable override external{
        bool isSupDe_;
        uint256 _amount;
        require(isOpen == true,"Closing");
        require(deCoinList[type_] == true, "Recharge in this currency is not supported");

        require(IERC20(type_).balanceOf(msg.sender) >= amount_, "Balance insufficient");
        require(IERC20(type_).allowance(msg.sender,address(this)) >= amount_,"No authorization");

        uint256 balance =  IERC20(type_).balanceOf(msg.sender);
        IERC20(type_).transferFrom(msg.sender,address(this),amount_);
        require(IERC20(type_).balanceOf(msg.sender) == balance-amount_, "Balance insufficient");
        
        (uint256 va,) = estimateFee(msg.sender);
        require(va <= msg.value,"not enough native for fees");

        if(isSupDe[type_] == true){
            isSupDe_=true;
            uint256 _oldTotalValue = getTotalValue(usdt);
            _depositToAAVE(type_,amount_);
            totalPrincipal += amount_;

            if( amount_ +_oldTotalValue - getTotalValue(usdt) == 1 ) {
               _amount = getTotalValue(usdt)+1;
            }
        }
        _amount = getTotalValue(usdt);

        _sentToL1(dstChainId,abi.encode(msg.sender,type_,amount_,isSupDe_, OperateType.DEPOSIT, _amount - totalPrincipal),msg.value);

        emit eventDeposit(type_,amount_,msg.sender);
    }

    function depositETH(uint256 amount_) override external payable {
        require(isOpen == true,"closing");
        (uint256 va,) = estimateFee(msg.sender);
        require(amount_+va <= msg.value,"amount no match");
        require(va <= msg.value,"not enough native for fees");
        
        _sentToL1(dstChainId,abi.encode(msg.sender,address(0),amount_,false,OperateType.DEPOSITETH,getTotalValue(usdt) - totalPrincipal),va);
        emit eventDepositETH(amount_,msg.sender);
    }

    function setSupDe(address add_,bool re) external onlyOwner {
        isSupDe[add_] = re;
    }
    
    function withdraw(uint256[] memory amount_,address[] memory coinType_) override external{
        require(isOpen == true,"closing");
        Account storage _ac  = accounts[msg.sender];
        require(amount_.length == coinType_.length,"Array mismatch");

        for(uint256 i = 0; i<amount_.length; i++ ){
            uint256 balance = _ac.capitalBalance[coinType_[i]];
            require(balance >= amount_[i],"Balance insufficient");
            _ac.capitalBalance[coinType_[i]] -= amount_[i];
            
            if(coinType_[i] == address(0)){
                payable(msg.sender).transfer(amount_[i]);
            }else{
                bool  transfer= IERC20(coinType_[i]).transfer(msg.sender, amount_[i]);
                require(transfer == true,"Withdraw failed");
            }
        }
        emit eventWithdraw(coinType_,amount_,msg.sender);
    }

    function verifyEcrecover(bytes32  messageHash, bytes memory signature) public pure returns(address recoveredAddress) {
        bytes32 hash = hashMessage(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = recover(signature);
        return  ecrecover(hash, v, r, s);
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

    // function getNativeFee(address user_)view public returns(uint){
    //     Account  storage account = accounts[user_]; 
    //     return (account.nativeFee);
    // }

    // function  getInterest(address user_) external view returns(uint256) {
    //     return  interestAmount[user_];
    // }

    function setWhilLlist(address  add,uint256 type_) external onlyOwner{
        if(type_==1) {
             _setupRole(NODE_ROLE,add);
        }else if(type_ == 2){
            _setupRole(FEE_ROLE,add);
        }
    }

    //利息大结算之后,直接把最新的利息分配到L1,然后维护L1和L2账本
    function withdrawInterest(uint256 amount_,address coinType_) public {
        require(isOpen == true,"closing");
        require(interestAmount[msg.sender] >= amount_,"Not sufficient funds");
        interestAmount[msg.sender] -= amount_;
        IERC20(coinType_).transfer(msg.sender ,amount_);
        emit eventWithdrawInterest(msg.sender, coinType_, amount_);
    }

    function getBalance(address address_) public view returns (address,bytes32,address[] memory, uint256 [] memory,uint256) {
        Account storage account = accounts[address_]; 
        uint256 count = 0;

        for (uint256 i = 0; i < coinList.length; i++) {
            if (account.capitalBalance[coinList[i]] != 0) {
                count++;
            }
        }

        address[] memory coin = new address[](count);
        uint256[] memory amount = new uint256[](count); 

        uint256 index = 0;
        for (uint256 i = 0; i < coinList.length; i++) {
            if (account.capitalBalance[coinList[i]] != 0) {
                coin[index] = coinList[i];
                amount[index] = account.capitalBalance[coinList[i]];
                index++;
            }
        }
        return (account.user,account.capitalMerkleRoot,coin,amount,account.capitalNonce);
    }

    function setAdapterParams(uint16 version,uint  gasForDestinationLzReceive) onlyOwner public {
        adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
    }

    // Function to get the USDT balance of the user
    // function getBalanceFromAAVE(address type_,address fromAdd_) public view returns (uint256) {
    //     // // Get the user data of the current address
    //     (uint256 currentBalance,, uint256 currentBorrowBalance,,,,, ) = getUserReserveData(type_, fromAdd_);
    //     uint256 usdtBalance = currentBalance - currentBorrowBalance;
    //     return usdtBalance;
    // }

    // function getUserReserveData(address asset, address user)    
    //     public
    //     view
    //     returns (
    //     uint256 currentATokenBalance,
    //     uint256 currentStableDebt,
    //     uint256 currentVariableDebt,
    //     uint256 principalStableDebt,
    //     uint256 scaledVariableDebt,
    //     uint256 stableBorrowRate,
    //     uint256 liquidityRate,
    //     uint40 stableRateLastUpdated
    //     )
    // {
    //     DataTypes.ReserveData memory reserve =
    //     ILendingPool(aave).getReserveData(asset);
    //     currentATokenBalance = IERC20Metadata(reserve.aTokenAddress).balanceOf(user);
    //     currentVariableDebt = IERC20Metadata(reserve.variableDebtTokenAddress).balanceOf(user);
    //     currentStableDebt = IERC20Metadata(reserve.stableDebtTokenAddress).balanceOf(user);
    //     principalStableDebt = IStableDebtToken(reserve.stableDebtTokenAddress).principalBalanceOf(user);
    //     scaledVariableDebt = IVariableDebtToken(reserve.variableDebtTokenAddress).scaledBalanceOf(user);
    //     liquidityRate = reserve.currentLiquidityRate;
    //     stableBorrowRate = IStableDebtToken(reserve.stableDebtTokenAddress).getUserStableRate(user);
    //     stableRateLastUpdated = IStableDebtToken(reserve.stableDebtTokenAddress).getUserLastUpdated(
    //     user
    //     );
    // }
    
    function getATokenWithToken(address add_)public view  returns(address){
        // Get the aUSDT token instance from the lending pool
        return ILendingPool(aave).getReserveData(add_).aTokenAddress;
    }

    function getOracle(uint16 remoteChainId) external view returns (address _oracle) {
        bytes memory bytesOracle = lzEndpoint.getConfig(lzEndpoint.getSendVersion(address(this)), remoteChainId, address(this), 6);
        assembly {
            _oracle := mload(add(bytesOracle, 32))
        }
    }
    
    function getSize(address user_) public view returns( bytes memory encoded ){
        encoded =  abi.encode(user_,0, 0,10000,0,10,getTotalValue(usdt),1000000);
    }
    
    function estimateFee(address user_)public view returns (uint nativeFee, uint zroFee) {
        (uint native, uint zro) =lzEndpoint.estimateFees(dstChainId, address(this), getSize(user_), false, adapterParams);
        return (native,zro);
    }
 
    function setIsOpen(bool re_)onlyOwner public{
        isOpen = re_;
    }

    function _sentToL1(uint16 _dstChainId,bytes memory _data,uint256 value)private {
         _lzSend(_dstChainId, _data, payable(msg.sender), address(0x0), adapterParams,value);
    }

    function _depositToAAVE(address type_,uint256 amount_) private{
        IERC20(type_).approve(aave,amount_);
        require(IERC20(type_).allowance(address(this),aave) >= amount_,"No authorization");
        ILendingPool(aave).deposit(type_, amount_,address(this),0);
    }

    function _withdrawFromAAVE(address type_,uint256 amount_,address receiver_) private returns(uint256){
        return ILendingPool(aave).withdraw(type_, amount_,receiver_);
    }

    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
           
        }
    }

    function setDeCoinList(address [] memory coin_,bool re_) external onlyOwner  {
        for(uint256 i= 0; i<coin_.length; i++){
            deCoinList[coin_[i]] = re_;
        }
    }

    function hasRole(bytes32 role, address account) public view  returns (bool) {
        return _roles[role].members[account];
    }
    
    function _nonblockingLzReceive(uint16, bytes memory, uint64 nonce, bytes memory encoded_) internal override {

        (uint256 type_) = abi.decode(encoded_,(uint256));
        if(type_ == 1){ // 提币
            ( ,InData memory data) = abi.decode(encoded_,(uint256,InData));

            bytes memory encodedData = abi.encodePacked(
                data.user,
                data.capitalMerkleRoot,
                abi.encodePacked(data.coinList),
                abi.encodePacked(data.withdrawnValues),
                data.nativeFee,
                data.checkOutType
            );

            require(hasRole(NODE_ROLE, verifyEcrecover(data.messageHash, data.signature)) == true,"The signer is not a node");
            bytes32 newMessageHash = keccak256(encodedData);
            require(newMessageHash  == data.messageHash ,"Incorrect data"); 

            Account storage myAccount = accounts[data.user];
            myAccount.user = data.user;
            myAccount.capitalMerkleRoot =  data.capitalMerkleRoot;
            myAccount.nativeFee = data.nativeFee;

            for(uint256 i =0 ; i < data.coinList.length; i++){
                isCoinList(data.coinList[i]);
                myAccount.capitalBalance[data.coinList[i]] += data.withdrawnValues[i];
                if(isSupDe[data.coinList[i]]){
                    if( data.withdrawnValues[i] > 0){
                        _withdrawFromAAVE(data.coinList[i], data.withdrawnValues[i], address(this));
                        totalPrincipal -= data.withdrawnValues[i];
                    }
                }
            }
            emit eventReceive(data.user,data.coinList,data.withdrawnValues,1);
        }else if(type_ == 2){ // 提利息
            ( ,uint256 interestBalance,address user_) = abi.decode(encoded_,(uint256,uint256,address));
            if(interestBalance  > 0){
                interestAmount[user_] += interestBalance;
                _withdrawFromAAVE(usdt, interestBalance, address(this));
            }
            emit eventReceiveInterest(user_, usdt, interestBalance, 2);
        }else  if(type_ == 3){ // 提手续费
            ( ,address[] memory add_,uint256[] memory amount_) = abi.decode(encoded_,(uint256,address[],uint256[]));
            for(uint256 i=0; i< add_.length; i++){
                totalFee[add_[i]] = amount_[i];
                if(isSupDe[add_[i]] && amount_[i] > 0){
                    _withdrawFromAAVE(usdt, amount_[i], address(this));
                }
            }
            emit eventReceive(address(0), add_ , amount_, 3);
        }else  if(type_ == 4){ // 用户自己大结算
            ( ,address user_,address[]memory coinList,uint256[] memory amount_, ) = abi.decode(encoded_,(uint256,address,address[],uint256[],uint256));
            Account storage myAccount = accounts[user_];
            myAccount.user = user_;
        
            for(uint256 i =0 ; i < coinList.length; i++){
                myAccount.capitalBalance[coinList[i]] += amount_[i];
                if(isSupDe[coinList[i]] && amount_[i] > 0){
                    _withdrawFromAAVE(coinList[i], amount_[i], address(this));
                }
            }
            emit eventReceive(user_, coinList , amount_, 4);
        }
    }

    function setOracle(uint16 dstChainId, address oracle) external onlyOwner {
        uint TYPE_ORACLE = 6;
        // set the Oracle
        lzEndpoint.setConfig(lzEndpoint.getSendVersion(address(this)), dstChainId, TYPE_ORACLE, abi.encode(oracle));
    }
    
    function hashMessage(bytes32  message) public pure returns (bytes32 messageHash) {
        messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return messageHash;
    }

    function isCoinList(address goodsAddress) private{
        if(isTrueForCoin[goodsAddress] == false){
            isTrueForCoin[goodsAddress] = true;
            coinList.push(goodsAddress);
        }
    }

    function withdrawFee(address add_, uint256 amount_) external{
        require(totalFee[add_] >= amount_,"Not sufficient funds");
        require(hasRole(FEE_ROLE,msg.sender)==true,"Permission Denied");
        totalFee[add_] -= amount_;
        if(add_ == address(0)){
            payable(msg.sender).transfer(amount_);
        }else{
            IERC20(add_).transfer(msg.sender ,amount_);
        }
        emit eventWithdrawFee(msg.sender, add_, amount_);
    }

    function getAllFee() external view returns(address[] memory coin,uint256[] memory amount){
        uint256 count = 0;
        for(uint256 i =0; i<coinList.length; i++){
            if(totalFee[coinList[i]] > 0){
                count++;
            }
        }

        coin = new address[](count);
        amount = new uint256[](count);
        
        uint256 index = 0;
        for(uint256 i =0; i<coinList.length; i++){
            if(totalFee[coinList[i]] > 0){
                coin[index] = coinList[i];
                amount[index] = totalFee[coinList[i]];
                index++;
            }
        }
    }

    function getTotalValue(address asset)    
        public
        view
        returns (
            uint256 currentATokenBalance
        )
    {
        DataTypes.ReserveData memory reserve =
        ILendingPool(aave).getReserveData(asset);
        currentATokenBalance = IERC20Metadata(reserve.aTokenAddress).balanceOf(address(this));
    }

}
