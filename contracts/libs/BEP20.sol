// SPDX-License-Identifier: MIT

// Test Finance //

// Farm Token //

pragma solidity >=0.6.0;



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
contract BEP20 is Context, IBEP20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    // The operator can only update the tokenomics functions to protect tokenomics
    //i.e some wrong setting and a pools get too much allocation accidentally
    address private _operator;

    mapping (address => uint256) private _balances;
  
    mapping (address => mapping(address => uint256)) private _allowances;


    string private _name;
    string private _symbol;
    uint8 private _decimals;

    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
   
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    uint256 public constant _maxSupply = 180 * 10**9 * 10**18;
    uint256 public _totalMinted = 0;

    uint256 private _maxMintable = 159000000 * 10 ** 18; // 159 million max mintable (180 million max - 21 million premined)
    uint256 private _totalSupply = 21000000 * 10 ** 18; // 10 million airdrop + 10 million locked liquidity + 1 million marketing/partnership
    
    uint256 private dropLiqAmount = 10000000 * 10 ** 18;
    uint256 private marketingAmount = 1000000 * 10 ** 18;

    address private airdropAddress = 0x7448343B38a224C639c81767095DCF7dBC7A2d3d;
    
    address private liquiditylockAddress = 0x0000a97418E2161634c90c8a06a2E18000223B95;
    
    address private marketingAddress = 0xB59448fBa4D9d8241a403e9Da7da11856EaaA0B1;
    
    // Events

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
      
        _operator = msg.sender; 
        


         _balances[airdropAddress] = dropLiqAmount;
         _balances[liquiditylockAddress] = dropLiqAmount;
         _balances[marketingAddress] = marketingAmount;

         emit Transfer(address(0), airdropAddress, dropLiqAmount);
         emit Transfer(address(0), liquiditylockAddress, dropLiqAmount);
         emit Transfer(address(0), marketingAddress, marketingAmount);

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
        return _totalSupply;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function totalMinted() public view returns (uint256) {
        return _totalMinted;
    }

    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, 'BEP20: transfer amount exceeds allowance')
        );
        return true;
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
               
        require(_totalSupply.add(amount) <= _maxSupply, 'Amount Exceeds Max Supply');
        
        _totalSupply = _totalSupply.add(amount);
        _totalMinted = _totalMinted.add(amount);
        
        _balances[account] = _balances[account].add(amount);

        emit Transfer(address(0), account, amount);

    }

    //Burn Tokens that are stuck on contract with no owner
    function burn(uint256 _amount) public onlyOperator {     
        require(_balances[address(this)] >= _amount,'Burning more than the current tokens on contract!');
        _transfer(address(this), BURN_ADDRESS, _amount);
        _totalSupply = _totalSupply.sub(_amount);
        _balances[address(this)].sub(_amount);

    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), 'BEP20: transfer from the zero address');
        require(recipient != address(0), 'BEP20: transfer to the zero address');

        _balances[sender] = _balances[sender].sub(amount, 'BEP20: transfer amount exceeds balance');
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }    
}