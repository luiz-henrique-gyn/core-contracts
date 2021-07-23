// SPDX-License-Identifier: MIT

/**
// Zaigar Finance //

Tokenomics:  
        Total Fees: 5.00000%  
        --->Burn Fees: 1.00000%  
        --->Holders Rewards: 2.000000%  
        --->Lp Pool: 0.000000%
        -->Marketing & development: 2.00000%   
*/

pragma solidity >=0.6.0;


import '../interfaces/IPancakeFactory.sol';
import '../interfaces/IPancakePair.sol';
import '../interfaces/IPancakeRouter01.sol';
import '../interfaces/IPancakeRouter02.sol';

import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';
import '@pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';

/**
 * @dev Implementation of the {IBEP20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {BEP20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-BEP20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of BEP20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IBEP20-approve}.
 */
contract RGBEP20 is Context, IBEP20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    // The operator can only update the tokenomics functions to protect tokenomics during pre sale and construction
    //i.e some wrong setting and a pools get too much allocation accidentally
    address private _operator;


    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => bool) private _claimedAirdrop;

  
    mapping (address => mapping(address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;
  
    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 public constant _maxSupply = 180 * 10**9 * 10**18;

    uint256 public _totalMinted = 0;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

   // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    
    // Max transfer amount rate in basis points. (default is 0.5% of total supply) // no limit for pre-sale
    uint16 public maxTransferAmountRate = 1000;
    // Addresses that excluded from antiWhale
    mapping(address => bool) private _excludedFromAntiWhale;

    // Pre sale Variables
     
    uint256 public aSBlock; 
    uint256 public aEBlock; 
    uint256 public aCap; 
    uint256 public aTot; 
    uint256 public aAmt; 

    
    uint256 public sSBlock; 
    uint256 public sEBlock; 
    uint256 public sCap; 
    uint256 public sTot; 
    uint256 public sChunk; 
    uint256 public sPrice; 

    bool airdropFinished = false;

  
    uint256 public _taxFee = 200;
    uint256 private _previousTaxFee = _taxFee;
    
    uint256 public _liquidityFee = 0;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _burnFee = 100;
    uint256 private _previousBurnFee = _burnFee;

    uint256 public _marketingFee = 200;
    address public marketingWallet = 0x7448343B38a224C639c81767095DCF7dBC7A2d3d;
    uint256 private _previousmarketingFee = _marketingFee;

    //initial amount for marketing on presale
    uint256 public marketingAmount = 100000*10**18; // 100k

    uint256 public transferFeeRate = _taxFee + _burnFee + _marketingFee + _liquidityFee; // Default 5% total 


    address private zaiRouterAddress = 0x8F767927973edE1c0DAe4787939e0a42D7acb4Bf;
    address private pancakeRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;

	
    uint256 private numTokensSellToAddToLiquidity = 2000*10**18;
    
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    uint256 private constant MAX = ~uint256(0);
    uint256 private _maxMintable = 170000000 * 10 ** 18; // 170 million max mintable (180 million max - 10 million pre sale)
    uint256 private _tTotal = 10000000 * 10 ** 18; // 10 million pre sale
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    // Events
    event TransferTaxFeeUpdated(address indexed owner, uint256 previousTaxFee, uint256 newTaxFee);
    event TransferBurnFeeUpdated(address indexed owner, uint256 previousBurnFee, uint256 newBurnFee);
    event TransferLiquidityFeeUpdated(address indexed owner, uint256 _previousLiquidityFee, uint256 newLiquidityFee);
    event TransferMarketingFeeUpdated(address indexed owner, uint256 _previousMarketingFee, uint256 newMarketingFee);
    event maxTransferRateUpdated(address indexed owner, uint256 _previousMaxAmountRate, uint256 newMaxAmountRate);
  //  event sendViaCall(address indexed to, uint256 amount);
    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;

        
        _rOwned[address(this)] = _rTotal;

        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
        _excludedFromAntiWhale[BURN_ADDRESS] = true;
        
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(pancakeRouterAddress); // pancake mainnet 0x10ED43C718714eb63d5aA57B78B54704E256024E testnet 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
         // Create a zaigar finance or pancake pair for this new token
        pancakePair = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), _pancakeRouter.WETH());

        // set the rest of the contract variables
        pancakeRouter = _pancakeRouter;

        //exclude owner and this contract from fee and Rewards 
        // MasterChef contract excluded from Rewards by operator after deploy
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcluded[owner()] = true;
        _isExcluded[address(this)] = true;
        _isExcluded[BURN_ADDRESS] = true;
        
        _operator = msg.sender;

         //get Total and will transfer pre sale to presale contract 
         _tOwned[address(this)] = _tTotal;     
        
        
         emit Transfer(address(0), address(this), _tTotal);

         // will be reenabled after pre sale
         removeAllFee();

         _transferFromExcluded(address(this), marketingWallet, marketingAmount);

        // Airdrop - Presale amounts
        startAirdrop(block.number,99999999, 75*10**uint256(_decimals), 900000*10**uint256(_decimals)); 
        startSale(block.number, 99999999, 0, 140000*10**uint256(_decimals), 9000000*10**uint256(_decimals)); 
         
    }

        modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false
                && _excludedFromAntiWhale[recipient] == false
            ) {
                require(amount <= maxTransferAmount(), "ZAIF::antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }

    modifier onlyOperator() {
        require(_operator == msg.sender, "Operator: caller is not the operator");
        _;
    }

    function operator() public view returns (address) {
        return _operator;
    }

    function transferOperator(address newOperator) public onlyOperator {
        require(newOperator != address(0), "TransferOperator: new operator is the zero address");
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }

    function renounceOperation() public onlyOperator {
        emit OperatorTransferred(_operator, address(0));
        _operator = address(0);
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return owner();
    }

    /**
     * @dev Returns the token name.
     */
   function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function totalMinted() public view returns (uint256) {
        return _totalMinted;
    }

    
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        _transfer(sender, recipient, amount);
        return true;
    }

    //Presale Functions only

        
    function getAirdrop(address _refer) external returns (bool success){
        require(aSBlock <= block.number && block.number <= aEBlock);
        require(_claimedAirdrop[msg.sender] != true, 'Already claimed airdrop!');
        
        if(aTot.add(aAmt) > aCap){
            if(airdropFinished = false){
                aAmt = aCap.sub(aTot);
            }
        }   

        require(aTot.add(aAmt) < aCap || aCap == 0, 'Reached Airdrop cap!');
        require(airdropFinished != true, 'Reached Airdrop cap!');
        //aTot++;
        aTot = aTot.add(aAmt);

        if(msg.sender != _refer && balanceOf(_refer) != 0 && _refer != 0x0000000000000000000000000000000000000000 && _refer != address(this) && aTot < aCap){
        
            uint256 referAmt = aAmt.sub(25*10**uint256(_decimals));

            if(aTot.add(referAmt) > aCap){
                if(airdropFinished = false){
                 referAmt = aCap.sub(aTot);
                }
            }   

            _transferFromExcluded(address(this), _refer, referAmt);

            if(aTot.add(referAmt) <= aCap){
             aTot = aTot.add(referAmt);
            }
  
        }
       
        _transferFromExcluded(address(this), msg.sender, aAmt); 

        if(aTot == aCap){
            airdropFinished = true;
        }
  
        _claimedAirdrop[msg.sender] = true;
        return true;
    }

    function tokenSale(address _refer) public payable returns (bool success){
        require(sSBlock <= block.number && block.number <= sEBlock);

        uint256 _eth = msg.value;
        uint256 _ethToRefer = _eth.div(10); //10% of BNB used to bought send to Referral of the buyer
        uint256 _tkns;
        _tkns = (sPrice*_eth) / 1 ether;
        require(sTot.add(_tkns) < sCap || sCap == 0 ,'Reached Sale Cap!');
        sTot = sTot.add(_tkns); 
        //sTot++;
        if(msg.sender != _refer && balanceOf(_refer) != 0 && _refer != 0x0000000000000000000000000000000000000000 && _refer != address(this)){
       
        sendBNB(_refer,_ethToRefer);
       
        }
      
        _transferFromExcluded(address(this), msg.sender, _tkns);
        
        return true;
    }

    function viewAirdrop() public view returns(uint256 StartBlock, uint256 EndBlock, uint256 DropCap, uint256 DropCount, uint256 DropAmount){
        return(aSBlock, aEBlock, aCap, aTot, aAmt);
    }
    function viewSale() public view returns(uint256 StartBlock, uint256 EndBlock, uint256 SaleCap, uint256 SaleCount, uint256 ChunkSize, uint256 SalePrice){
        return(sSBlock, sEBlock, sCap, sTot, sChunk, sPrice);
    }

    function getDropAmount() public view returns(uint256 DropCount){
        return aTot;
    }

    function getSaleAmount() public view returns(uint256 SaleCount){
        return sTot;
    }

    
    function startAirdrop(uint256 _aSBlock, uint256 _aEBlock, uint256 _aAmt, uint256 _aCap) public onlyOwner() {
        aSBlock = _aSBlock;
        aEBlock = _aEBlock;
        aAmt = _aAmt;
        aCap = _aCap;
        aTot = 0;
    }
    function startSale(uint256 _sSBlock, uint256 _sEBlock, uint256 _sChunk, uint256 _sPrice, uint256 _sCap) public onlyOwner() {
        sSBlock = _sSBlock;
        sEBlock = _sEBlock;
        sChunk = _sChunk;
        sPrice =_sPrice;
        sCap = _sCap;
        sTot = 0;
    }
    function clearETH() public onlyOperator() {
        address payable _owner = msg.sender;
        _owner.transfer(address(this).balance);
    }
    fallback() external payable {

    }
    //

        /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), 'BEP20: mint to the zero address');
       
       uint256 predictedTotal = _totalMinted.add(amount);

        if (predictedTotal >= _maxMintable) {    
            amount = _maxMintable.sub(_totalMinted);
        } 
        
        require(_totalMinted <= _maxMintable , 'BEP20: Max Amount minted reached');
               
        require(_tTotal.add(amount) <= _maxSupply, 'Amount Exceeds Max Supply');
        
        _tTotal = _tTotal.add(amount);
        _totalMinted = _totalMinted.add(amount);
        
        if(isExcludedFromReward(account)){
         _tOwned[account] = _tOwned[account].add(amount);
        }else{
         _rOwned[account] = _rOwned[account].add(amount);
        }
        emit Transfer(address(0), account, amount);
    }

    //Burn Tokens that are not bought in presale
    function burn(uint256 _amount) public onlyOwner {     
        require(_tOwned[address(this)] >= _amount,'Burning more than the current tokens on contract!');
        _transferToExcluded(address(this), BURN_ADDRESS, _amount);
        emit Transfer(address(this), BURN_ADDRESS, _amount);
        _tTotal = _tTotal.sub(_amount);
        _tOwned[address(this)].sub(_amount);
    }

    /**
    * @dev Returns the max transfer amount.
    */
    function maxTransferAmount() public view returns (uint256) {
        return totalSupply().mul(maxTransferAmountRate).div(10000);
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    /**
    * @dev Returns the address is excluded from antiWhale or not.
    */
    function isExcludedFromAntiWhale(address _account) public view returns (bool) {
        return _excludedFromAntiWhale[_account];
    }

    /**
    * @dev Exclude or include an address from antiWhale.
    * Can only be called by the current operator/owner.
    */
    function setExcludedFromAntiWhale(address _account, bool _excluded) public onlyOperator() {
        _excludedFromAntiWhale[_account] = _excluded;
    }

    function updateTaxFee(uint256 taxFee) public onlyOperator() {
        emit TransferTaxFeeUpdated(msg.sender, _taxFee, taxFee);
        _taxFee = taxFee;
    }

    function updateBurnFee(uint256 burnFee) public onlyOperator() {
        _burnFee = burnFee;
    }

    function updateLiquidityFee(uint256 liquidityFee) public onlyOperator() {
         emit TransferLiquidityFeeUpdated(msg.sender, _liquidityFee, liquidityFee);
         _liquidityFee = liquidityFee;
    }

    function updateMarketingFee(uint256 marketingFee) public onlyOperator() {
         emit TransferMarketingFeeUpdated(msg.sender, _marketingFee, marketingFee);
         _marketingFee = marketingFee;
    }

    function updateMaxTransferAmount(uint16 _maxTransferAmountRate) public onlyOperator() {
        require(_maxTransferAmountRate < 2000, "Cannot set max transaction amount more than 20 percent!");
        emit maxTransferRateUpdated(msg.sender, _maxTransferAmountRate, maxTransferAmountRate);
        maxTransferAmountRate = _maxTransferAmountRate;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }


    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOperator() {
        require(account != 0x10ED43C718714eb63d5aA57B78B54704E256024E, 'We can not exclude Pancake router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOperator() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    

    
     //to recieve ETH from zaiRouter or pancakeRouter when swaping or presale
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10000);
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(10000);
    }
    
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is zaif pair.
        uint256 contractTokenBalance = balanceOf(address(this));        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != pancakePair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount);
    }


 

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to zaiswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the zaiswap or pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        _approve(address(this), address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeRouter), tokenAmount);

        // add the liquidity
        pancakeRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount) internal virtual antiWhale(sender, recipient, amount) {
       
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            removeAllFee();
        }
        
        //Calculate burn amount and marketing amount
        uint256 burnAmt = amount.mul(_burnFee).div(10000);
        uint256 marketingAmt = amount.mul(_marketingFee).div(10000);

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, (amount.sub(burnAmt).sub(marketingAmt)));
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, (amount.sub(burnAmt).sub(marketingAmt)));
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, (amount.sub(burnAmt).sub(marketingAmt)));
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, (amount.sub(burnAmt).sub(marketingAmt)));
        } else {
            _transferStandard(sender, recipient, (amount.sub(burnAmt).sub(marketingAmt)));
        }
        
        //Temporarily remove fees to transfer to burn address and marketing wallet
        _taxFee = 0;
        _liquidityFee = 0;

        //If burnAddress has >= 10 Billion (total supply <= 1 Billion)
        //don't take burnFee
       // if(balanceOf(address(0)) < 10 * 10**9 * 10**18){        
       
       // } 
        
        if(_isExcluded[sender]){
            _transferBothExcluded(sender, BURN_ADDRESS, burnAmt);
            _transferFromExcluded(sender, marketingWallet, marketingAmt);   
        }else{
            _transferToExcluded(sender, BURN_ADDRESS, burnAmt);
            _transferStandard(sender, marketingWallet, marketingAmt);   
        }

        if(burnAmt > 0){
            _tTotal = _tTotal.sub(burnAmt);
        }

        //Restore tax and liquidity fees
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;


        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            restoreAllFee();
        }
    }

    function sendBNB(address _to, uint256 amount) private {
        // Call returns a boolean value indicating success or failure.
        // To send referral BNB payment.
        require(address(this).balance > amount,'contract need more BNB');
        address payable wallet = address(uint256(_to));
        wallet.transfer(amount);

    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    
    function SwapAndLiquifyEnable() external onlyOperator() {
        require(inSwapAndLiquify = false, "It is already enabled!");
        inSwapAndLiquify = true;
        emit SwapAndLiquifyEnabledUpdated(true);
    }
    
    function SwapAndLiquifyDisable() external onlyOperator() {
        require(inSwapAndLiquify = true, "It is already disabled!");
        inSwapAndLiquify = false;
        emit SwapAndLiquifyEnabledUpdated(false);
    }

    //Programatically used for masterchef/token contract
    function removeAllFee() private {
        _taxFee = 0;
        _liquidityFee = 0;
        _burnFee = 0;
        _marketingFee = 0;
    }
    
 
    function restoreAllFee() private {
        _taxFee = 200;
        _liquidityFee = 0;
        _burnFee = 100;
        _marketingFee = 200;
    }

    //Call this function after finalizing the presale
    function enableAllFees() external onlyOperator() {
        _taxFee = 200;
        _liquidityFee = 0;
        _burnFee = 100;
        _marketingFee = 200;
    }


    function setmarketingWallet(address newWallet) external onlyOperator() {
        marketingWallet = newWallet;
    }
    
    //New Pancakeswap or own router version?
    //No problem, just change it!
    function setRouterAddress(address newRouter) public onlyOperator() {
        IPancakeRouter02 _newPancakeRouter = IPancakeRouter02(newRouter);
        pancakePair = IPancakeFactory(_newPancakeRouter.factory()).createPair(address(this), _newPancakeRouter.WETH());
        pancakeRouter = _newPancakeRouter;
    }
   

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOperator {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
}