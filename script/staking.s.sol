pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract staking {
uint256 public totalSupply;
mapping(address => uint) public balanceOf;
mapping(address => uint) public userRewardPerTokenPaid;
address public owner;
IERC20 public stakingToken;
IERC20 public rewardToken;

// Duration of rewards to be paid out (in seconds)
uint public duration;
// Timestamp of when the rewards finish
uint public finishAt;
// Minimum of last updated time and reward finish time
uint public updatedAt;
// Reward to be paid out per second
uint public rewardRate;
// Sum of (reward rate * dt * 1e18 / total supply)
uint public rewardPerTokenStored;
// User address => rewards to be claimed
mapping(address => uint) public rewards;


modifier onlyOwner() {
    require(msg.sender == owner, "not authorized");
    _;
}

modifier updateReward(address _account) {
    rewardPerTokenStored = rewardPerToken();
    updatedAt = lastTimeRewardApplicable();

    if (_account != address(0)) {
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }
    _;
} 


constructor(address _staking,address _reward){
    stakingToken = IERC20(_staking);
    rewardToken = IERC20(_reward);
    owner = msg.sender;
}

function lastTimeRewardApplicable() public view returns (uint) {
    return _min(finishAt, block.timestamp);
}

function rewardPerToken() public view returns (uint) {
    if (totalSupply == 0) {
        return rewardPerTokenStored;
    }

    return
        rewardPerTokenStored +
        (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
        totalSupply;
}

function stake(uint256 ammount) updateReward(msg.sender) external{
    require(ammount >0,"Invalid Ammount");
    stakingToken.transferFrom(msg.sender,address(this),ammount);
    totalSupply +=ammount;
    balanceOf[msg.sender]+=ammount;
}

function withdraw(uint256 _ammount) updateReward(msg.sender) external{
    require(_ammount>0,"Invalid Ammount");
    require(balanceOf[msg.sender] >= _ammount,"Not sufficient amount you staked");
    stakingToken.transferFrom(msg.sender,address(this),_ammount);
    totalSupply +=_ammount;
    balanceOf[msg.sender]+=_ammount;
}

function earned(address _account) public view returns (uint) {
    return
        ((balanceOf[_account] *
            (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
        rewards[_account];
}

function getReward() external updateReward(msg.sender) {
    uint reward = rewards[msg.sender];
    if (reward > 0) {
        rewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, reward);
    }
}

function setRewardsDuration(uint _duration) external onlyOwner {
    require(finishAt < block.timestamp, "reward duration not finished");
    duration = _duration;
}

function notifyRewardAmount(
    uint _amount
) external onlyOwner updateReward(address(0)) {
    if (block.timestamp >= finishAt) {
        rewardRate = _amount / duration;
    } else {
        uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
        rewardRate = (_amount + remainingRewards) / duration;
    }

    require(rewardRate > 0, "reward rate = 0");
    require(
        rewardRate * duration <= rewardToken.balanceOf(address(this)),
        "reward amount > balance"
    );

    finishAt = block.timestamp + duration;
    updatedAt = block.timestamp;
}

function _min(uint x, uint y) private pure returns (uint) {
    return x <= y ? x : y;
}

}