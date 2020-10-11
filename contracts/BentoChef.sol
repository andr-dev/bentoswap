// Much inspiration taken from MasterChef: https://github.com/sushiswap/sushiswap/blob/eee6ead30a627efa1775a60d5e72f4c757ceb5ec/contracts/MasterChef.sol
// Learn now, edit later :)

pragma solidity >=0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./BentoToken.sol";

interface Migrator {
  function migrate(IERC20 token) external returns (IERC20);
}

contract BentoChef is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
  }

  struct PoolInfo {
    IERC20 lpToken;           // The address of the LP token contract
    uint256 allocPoint;       // Allocation points assigned to this specific pool. Determines BENTOs to distribute per block.
    uint256 lastRewardBlock;  // Last block number for which rewards will be distributed
    uint256 accBentoPerShare; // Accumulated BENTO per share (times 1e12)
  }

  BentoToken public bento;
  address public devaddr;
  uint256 public bonusEndBlock;
  uint256 public bentoPerBlock;
  uint256 public constant bonusMultiplier = 10;

  mapping (uint256 => mapping (address => UserInfo)) public userInfo;

  PoolInfo[] public poolInfo;
  uint256 public totalAllocPoint = 0;
  uint256 public startBlock;

  constructor(
    BentoToken _bento,
    address _devaddr,
    uint256 _bentoPerBlock,
    uint256 _startBlock,
    uint256 _bonusEndBlock
  ) public {
    bento = _bento;
    devaddr = _devaddr;
    bentoPerBlock = _bentoPerBlock;
    bonusEndBlock = _bonusEndBlock;
    startBlock = _startBlock;
  }

  function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(PoolInfo({
      lpToken: _lpToken,
      allocPoint: _allocPoint,
      lastRewardBlock: lastRewardBlock,
      accBentoPerShare: 0
    }));
  }

  function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
    poolInfo[_pid].allocPoint = _allocPoint;
  }

  function migrate(uint256 _pid, Migrator _migrator) public onlyOwner {
    PoolInfo storage pool = poolInfo[_pid];
    IERC20 lpToken = pool.lpToken;
    updatePool(_pid);
    uint256 bal = lpToken.balanceOf(address(this));
    lpToken.safeApprove(address(_migrator), bal);
    IERC20 newLpToken = _migrator.migrate(lpToken);
    require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
    pool.lpToken = newLpToken;
  }

  function pendingBento(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accBentoPerShare = pool.accBentoPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (block.number > pool.lastRewardBlock && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
      uint256 bentoReward = multiplier.mul(bentoPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
      accBentoPerShare = accBentoPerShare.add(bentoReward.mul(1e12).div(lpSupply));
    }
    return user.amount.mul(accBentoPerShare).div(1e12).sub(user.rewardDebt);
  }

  function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
    if (_to <= bonusEndBlock) {
      return _to.sub(_from).mul(bonusMultiplier);
    } else if (_from >= bonusEndBlock) {
      return _to.sub(_from);
    } else {
      return bonusEndBlock.sub(_from).mul(bonusMultiplier).add(_to.sub(bonusEndBlock));
    }
  }

  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.number <= pool.lastRewardBlock) {
      return;
    }
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (lpSupply == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
    uint256 bentoReward = multiplier.mul(bentoPerBlock.mul(pool.allocPoint).div(totalAllocPoint));
    bento.mint(devaddr, bentoReward.div(10));
    bento.mint(address(this), bentoReward);
    pool.accBentoPerShare = pool.accBentoPerShare.add(bentoReward.mul(1e12).div(lpSupply));
    pool.lastRewardBlock = block.number;
  }

  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  function deposit(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accBentoPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        safeBentoTransfer(msg.sender, pending);
      }
    }
    if (_amount > 0) {
      pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
      user.amount = user.amount.add(_amount);
    }
    user.rewardDebt = user.amount.mul(pool.accBentoPerShare).div(1e12);
    // emit Deposit(msg.sender, _pid, _amount);
  }

  function withdraw(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "BentoChef::withdraw: insufficient balance");
    updatePool(_pid);
    uint256 pending = user.amount.mul(pool.accBentoPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0) {
      safeBentoTransfer(msg.sender, pending);
    }
    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      pool.lpToken.safeTransfer(address(msg.sender), _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accBentoPerShare).div(1e12);
    // emit Withdraw(msg.sender, _pid, _amount);
  }

  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(pool.lpToken != IERC20(address(0)), "emergencyWithdraw: wut?");
    pool.lpToken.safeTransfer(address(msg.sender), user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  function safeBentoTransfer(address _to, uint256 _amount) internal {
    uint256 bentoBal = bento.balanceOf(address(this));
    if (_amount > bentoBal) {
        bento.transfer(_to, bentoBal);
    } else {
        bento.transfer(_to, _amount);
    }
  }

  function dev(address _devaddr) public {
    require(msg.sender == devaddr, "dev: wut?");
    devaddr = _devaddr;
  }
}