/**
 * @title LP Token Wrapper
 * @dev LPTokenWrapper contract
 *
 * @author - <MIDGARD TRUST>
 * for the Midgard Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

import "./SafeERC20.sol";
import "./SafeMath.sol";
import "./IReferrals.sol";
import "./IWhitelist.sol";

pragma solidity 0.6.12;


contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // outputs the external contracts.
    IWhitelist public whitelist; // external whitelist contract 
    IReferrals public referrals; // external referrals contract 

    uint256 public constant DURATION = 1 days; // distribution time 

    address public stakingCoinAddress; // coin that can be staked
    address public rewardCoinAddress; // the coin distributed for staking
    address public vaultAddress; // where the rewards come from
    address public feeReciver; // address that gets the penalties 

    uint256 private _totalSupply; // total deposited staking coins

    mapping(address => uint256) private balances; // address deposited staking coins
    mapping(address => uint256) public requestedWithdrawTime; // address requested Payout Time
    mapping(address => bool) public acceptPenaltyFee; // has the address accepted the penalty fee
    mapping(address => uint256) public userRewardPerTokenPaid; // how many coins did an address get per staked token 
    mapping(address => uint256) public rewards; // how much did an address get paid 

    uint256[] public refLevelReward = [40000,30000,10000,10000,5000,5000]; // Allocation of ref fees over the ref level 

    uint256 public lockTime = 2592000; // how long are the coins locked | 30 days
    uint256 public penaltyFee = 800000000; // the maximum penalty fee a user has to pay | 80%
    uint256 public timeFrame = 1; // Unit of time how to be underpaid | 1s
    uint256 public rewardCoinFee = 99900; // tranfer fee from the reward coin (10000 = 0%) 
    uint256 public refRewardFee = 5000; // ref reward from the staking (5000 = 5%)
    uint256 public refLevel = 6; // ref Levels for the ref Reward
    uint256 internal normalPercent = 100000 - refRewardFee; // Payout percentage without refs 
    uint256 public emergencyTime = 7 days; // how long you can make a free instant emergency withdrawal 
    uint256 public freeTime = 172800; // how long you have to make a withdrawal after the lock time has expired | 2 days
    uint256 public periodFinish = 0; // when is the drop finished 
    uint256 public rewardRate = 0; // how many coins are credited 
    uint256 public lastUpdateTime;  // when was the last update 
    uint256 public rewardPerTokenStored;  // how many coins did a Token get
    uint256 public ReceivedRewardCoins; // How many reward coins the contract has received

    // return total deposited staking coins
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // return deposited staking coins from address
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    // stake "staking coin" to the pool
    function stake(uint256 _amount) public virtual {
        _totalSupply = _totalSupply.add(_amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);
        IERC20(stakingCoinAddress).safeTransferFrom(msg.sender, address(this), _amount);
    }

    // withdraw "staking coin" from the pool (when the address is in the withdraw time or  accept the penalty fee)
    function withdraw(uint256 _amount) public virtual{
        _totalSupply = _totalSupply.sub(_amount);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        if (block.timestamp > requestedWithdrawTime[msg.sender].add(lockTime) && block.timestamp < requestedWithdrawTime[msg.sender].add(lockTime).add(freeTime) || whitelist.isWhitelisted(msg.sender) == true) {
        IERC20(stakingCoinAddress).safeTransfer(msg.sender, _amount);
        }
        else{
        require(acceptPenaltyFee[msg.sender] == true, "You must first accept the penalty Fee or wait until the lock ends");
        uint256 userAmount = _amount.mul(remainingPenaltyFee(msg.sender).div(1000000000));
        uint256 feeAmount = _amount.sub(userAmount);
        IERC20(stakingCoinAddress).safeTransfer(msg.sender, userAmount);
        IERC20(stakingCoinAddress).safeTransfer(feeReciver, feeAmount);
    }
    }

    // emergency withdraw "staking coin" from the pool #SAFU
    function emergencyWithdraw(uint256 _amount) public virtual{
        require (block.timestamp < emergencyTime, "no emergency");
        _totalSupply = _totalSupply.sub(_amount);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        IERC20(stakingCoinAddress).safeTransfer(msg.sender, _amount);
    }

    // indicates how much penalty interest is still left until the free payout 
    function remainingPenaltyFee(address _account) public view returns (uint256) {

     uint256 endTime = requestedWithdrawTime[_account].add(lockTime);
     uint256 penaltyFeePeerDay = penaltyFee.div(lockTime.div(timeFrame));
     if (block.timestamp < endTime) {
     uint256 remainingTime = endTime.sub(block.timestamp);
     uint256 penaltyInterestPercent = remainingTime.div(timeFrame).mul(penaltyFeePeerDay);

    return penaltyInterestPercent;
    
     } else {

         return 0;
}
}
}