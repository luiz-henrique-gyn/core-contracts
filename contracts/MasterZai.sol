// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

/*
 * ZaigarFinance 
 */

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v3.4.1


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

import "./ZafiraToken.sol";



// import "@nomiclabs/buidler/console.sol";

// MasterZai is the master of ZAFI 
// He can make Zaif and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ZAFI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterZai is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ZAFIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accZafiPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accZafiPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. ZAFIs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that ZAFIs distribution occurs.
        uint256 accZafiPerShare; // Accumulated ZAFIs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
        uint256 totalLp;            // Total Token in Pool
    }

    // The ZAFI TOKEN!
    ZafiraToken public zafi;

    //On Distribution Dev address.
    address public devaddr;
    // Deposit Fee address
    address public feeAddress;
    //On Distribution Marketing Address
    address public marktAddress;
    //On Distribution Staff team Address
    address public staffAddress; 
    // ZAFI tokens created per block.
    uint256 public zafiPerBlock;
    // Bonus muliplier for early zafi makers.
    uint256 public BONUS_MULTIPLIER = 1;

    
    // 10% for Marketing on distribution
    uint16 public constant blockMktFee = 1000;

    // 4% for salary on distribution
    uint16 public constant blockStaffFee = 400;

    // 1% for development on distribution
    uint16 public constant blockDevFee = 100;

    uint256 currentDevFee = 0;
    uint256 currentStaffFee = 0;
    uint256 currentMarketingFee = 0;


    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when ZAFI mining starts.
    uint256 public startBlock;
    // Total ZAFI in ZAFI Pools (can be multiple pools)
    uint256 public totalZafiInPools = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);

    constructor(
        ZafiraToken _zafi,
        address _devaddr,
        address _feeAddress,
        address _marktAddress,
        address _staffAddress,
        uint256 _zafiPerBlock,
        uint256 _startBlock,
        uint256 _multiplier

    ) public {
        zafi = _zafi;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        marktAddress = _marktAddress;
        staffAddress = _staffAddress;
        zafiPerBlock = _zafiPerBlock;
        startBlock = _startBlock;
        BONUS_MULTIPLIER = _multiplier;

        totalAllocPoint = 0;

    }

    modifier validatePool(uint256 _pid) {
        require(_pid < poolInfo.length, "validatePool: pool exists?");
        _;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Detects whether the given pool already exists
    function checkPoolDuplicate(IBEP20 _lpToken) public view {
        uint256 length = poolInfo.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            require(poolInfo[_pid].lpToken != _lpToken, "add: existing pool");
        }
    }

    fallback() external payable {

    }


    //actual Zaif left in MasterChef can be used in rewards, must excluding all in zafi pools
    //this function is for safety check 
    function remainRewards() public view returns (uint256) {
        return zafi.balanceOf(address(this)).sub(totalZafiInPools);
    }

    //All Zaifs that are not in pools or masterchef reward stack
    function getCirculatingSupply() external view returns(uint256) {
        uint256 tSupply = zafi.totalSupply();
        uint256 zaifBalance = zafi.balanceOf(address(this));

        return tSupply.sub(zaifBalance);    
    }


     // Add a new lp to the pool. Can only be called by the owner.
    // Can add multiple pool with same lp token without messing up rewards, because each pool's balance is tracked using its own totalLp
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
       require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
        lpToken: _lpToken,
        allocPoint: _allocPoint,
        lastRewardBlock: lastRewardBlock,
        accZafiPerShare: 0,
        depositFeeBP: _depositFeeBP,
        totalLp : 0
        }));
    }

    // Update the given pool's ZAFI allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending ZAFIs on frontend.
    function pendingZafi(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accZafiPerShare = pool.accZafiPerShare;
        //uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 lpSupply = pool.totalLp;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 zafiReward = multiplier.mul(zafiPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            uint256 totalRewardFees = zafiReward.mul(1500).div(10000);
            uint256 zafiRewardUsers = zafiReward.sub(totalRewardFees);

            uint256 totalminted = zafi.totalMinted();
             
        if(totalminted >= 159000000000000000000000000){
         
            accZafiPerShare = accZafiPerShare;

            }else{
                accZafiPerShare = accZafiPerShare.add(zafiRewardUsers.mul(1e12).div(lpSupply));
            }

        }
  
         return user.amount.mul(accZafiPerShare).div(1e12).sub(user.rewardDebt);

    }

        // View function to see all locked ZAFIs on frontend.
        function lockedZafi() external view returns (uint256) {
            return totalZafiInPools;
        }

    // Update reward variables for all pools. Be careful of gas spending! 

    function massUpdatePools() public {
       
        uint256 length = poolInfo.length;

        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
         
    }
 
    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
       
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.totalLp == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 zafiReward = multiplier.mul(zafiPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
    
        uint256 totalRewardFees = zafiReward.mul(1500).div(10000);

        //Total - 15% fees
        uint256 zafiRewardUsers = zafiReward.sub(totalRewardFees);
       
        uint256 totalminted = zafi.totalMinted();
       
        if(totalminted >= 159000000000000000000000000){
         
            if(currentDevFee > 0 || currentStaffFee > 0 || currentMarketingFee > 0){

             safeZafiTransfer(devaddr,currentDevFee);
             safeZafiTransfer(staffAddress,currentStaffFee);
             safeZafiTransfer(marktAddress,currentMarketingFee);

            }
  
            pool.accZafiPerShare = pool.accZafiPerShare;

            currentDevFee = 0;
            currentMarketingFee = 0;
            currentStaffFee = 0;

        }else{
             
             zafi.mint(address(this),zafiReward);

                if(currentDevFee > 1100000000000000000000){
                
                    safeZafiTransfer(devaddr,currentDevFee);
                    currentDevFee = 0;

                } else if(currentStaffFee > 1100000000000000000000){
                    
                    safeZafiTransfer(staffAddress,currentStaffFee);
                    currentStaffFee = 0;

                } else if(currentMarketingFee > 2000000000000000000000){
                    
                    safeZafiTransfer(marktAddress,currentMarketingFee);
                    currentMarketingFee = 0;

                }

             }

            //1% dev fee
            currentDevFee = currentDevFee.add(zafiReward.mul(blockDevFee).div(10000));

            //4% staff fee
            currentStaffFee = currentStaffFee.add(zafiReward.mul(blockStaffFee).div(10000));
            
            //10% marketing fee
            currentMarketingFee = currentMarketingFee.add(zafiReward.div(10));
 
            pool.accZafiPerShare = pool.accZafiPerShare.add(zafiRewardUsers.mul(1e12).div(pool.totalLp));
            pool.lastRewardBlock = block.number;

   }         
        

    // Deposit LP tokens to MasterZai for ZAFI allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.number >= startBlock, "MasterChef:: Can not deposit before farm start");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
       

        updatePool(_pid);      
        

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accZafiPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                uint256 currentRewardBalance = remainRewards();
                if(currentRewardBalance > 0) {
                    if(pending > currentRewardBalance) {
                        safeZafiTransfer(msg.sender, currentRewardBalance);
                    } else {
                        safeZafiTransfer(msg.sender, pending);
                    }
                }
            }
        }
        
        if (_amount > 0) {

            if (pool.depositFeeBP > 0) {

                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);

                if (address(pool.lpToken) == address(zafi)) {
                    totalZafiInPools = totalZafiInPools.add(_amount).sub(depositFee);   
                } 

                pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
                pool.lpToken.safeTransfer(feeAddress, depositFee);

                user.amount = user.amount.add(_amount).sub(depositFee);
                pool.totalLp = pool.totalLp.add(_amount).sub(depositFee);

            } else {
                user.amount = user.amount.add(_amount);
                pool.totalLp = pool.totalLp.add(_amount);

                if (address(pool.lpToken) == address(zafi)) {
                    totalZafiInPools = totalZafiInPools.add(_amount);
                }

                pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
                                
           }
        }

        user.rewardDebt = user.amount.mul(pool.accZafiPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterZai.
    function withdraw(uint256 _pid, uint256 _amount) public validatePool(_pid) nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        //this will make sure that user can only withdraw from his pool
        //cannot withdraw more than pool's balance and from MasterChef's token
        require(pool.totalLp >= _amount, "Withdraw: Pool total LP not enough");


        updatePool(_pid);      
        

        uint256 pending = user.amount.mul(pool.accZafiPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                uint256 currentRewardBalance = remainRewards();
                //additional checkings
                if(currentRewardBalance > 0) {
                    if(pending > currentRewardBalance) {
                        safeZafiTransfer(msg.sender, currentRewardBalance);
                    } else {
                        safeZafiTransfer(msg.sender, pending);
                    }
                }
            }
            
        if(_amount > 0) {
                
             if (address(pool.lpToken) == address(zafi)) {
      
                 uint256 zafiBal = zafi.balanceOf(address(this));

                 require(_amount <= zafiBal,'withdraw: not good');    

                if(_amount >= totalZafiInPools){
                    totalZafiInPools = 0;
                }else{
                    require(totalZafiInPools >= _amount,'amount bigger than pool wut?');
                    totalZafiInPools = totalZafiInPools.sub(_amount);
                }  

                pool.lpToken.safeTransfer(address(msg.sender), _amount);
                
            } else {
                pool.lpToken.safeTransfer(address(msg.sender), _amount);
            }
        }
        
        user.amount = user.amount.sub(_amount);
        pool.totalLp = pool.totalLp.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accZafiPerShare).div(1e12);
        
        emit Withdraw(msg.sender, _pid, _amount);

    }


    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        require(pool.totalLp >= amount, "EmergencyWithdraw: Pool total LP not enough");

        if (address(pool.lpToken) == address(zafi)) {
          
            uint256 zafiBal = zafi.balanceOf(address(this));

            require(amount <= zafiBal,'withdraw: not good'); 

            if(amount >= totalZafiInPools){
                totalZafiInPools = 0;
            }else{
                require(totalZafiInPools >= amount,'amount bigger than pool wut?');
                totalZafiInPools = totalZafiInPools.sub(amount);
            }  

            pool.lpToken.safeTransfer(address(msg.sender), amount);

        }else{ 
            pool.lpToken.safeTransfer(address(msg.sender), amount);
        }

        user.amount = 0;
        user.rewardDebt = 0;
        pool.totalLp = pool.totalLp.sub(amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);

    }

    function getPoolInfo(uint256 _pid) public view
    returns(address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accZafiPerShare, uint16 depositFeeBP, uint256 totalLp) {
        return (address(poolInfo[_pid].lpToken),
             poolInfo[_pid].allocPoint,
             poolInfo[_pid].lastRewardBlock,
             poolInfo[_pid].accZafiPerShare,
             poolInfo[_pid].depositFeeBP,
             poolInfo[_pid].totalLp);
    }

    // Safe zafi transfer function, just in case if rounding error causes pool to not have enough ZAFIs.
    function safeZafiTransfer(address _to, uint256 _amount) internal {
        if(zafi.balanceOf(address(this)) > totalZafiInPools){
            //zafiBal = total zafi in MasterChef - total zafi in zafi pools, this will make sure that MasterChef never transfer rewards from deposited zafi pools
            uint256 zafiBal = zafi.balanceOf(address(this)).sub(totalZafiInPools);
            if (_amount >= zafiBal) {
                zafi.transfer(_to, zafiBal);
            } else if (_amount > 0) {
                zafi.transfer(_to, _amount);
            }
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

     //deposit fee in pools update
     function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    // Pancake has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _zafiPerBlock) public onlyOwner {
        massUpdatePools();
        emit EmissionRateUpdated(msg.sender, zafiPerBlock, _zafiPerBlock);
        zafiPerBlock = _zafiPerBlock;
    }

}
