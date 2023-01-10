/**
 * @title Bribe
 * @dev Bribe.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.11;

import "./SafeERC20.sol";
import "./Math.sol";
import "./Ownable.sol";
import "./IReferrals.sol";
import "./IGaugeFactory.sol";

contract Bribe is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant DURATION = 7 days; // rewards are released over 7 days

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }
    mapping(address => Reward) public rewardData;
    mapping(address => bool) public isRewardToken;
    address[] public rewardTokens;
    address public gaugeFactory;
    address public bribeFactory;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;
    mapping(address => mapping(address => bool)) public whitelisted;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /**
     * @dev Outputs the fee variables.
     */
    uint256 public referralFee;
    uint256[] public refLevelPercent = [6000, 3000, 1000];
    // user -> reward token -> earned amount
    mapping(address => mapping(address => uint256)) public earnedRefs;
    address public referralContract;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _owner,
        address _gaugeFactory,
        address _bribeFactory
    ) public Ownable(_owner) {
        require(
            _bribeFactory != address(0) &&
                _gaugeFactory != address(0) &&
                _owner != address(0)
        );
        gaugeFactory = _gaugeFactory;
        bribeFactory = _bribeFactory;
        referralContract = IGaugeFactory(gaugeFactory).baseReferralsContract();
        referralFee = IGaugeFactory(gaugeFactory).baseReferralFee();
    }

    function left(address _rewardsToken)
        external
        view
        returns (uint256 leftover)
    {
        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            leftover = 0;
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish -
                block.timestamp;
            leftover = remaining * rewardData[_rewardsToken].rewardRate;
        }
    }

    function addRewardtoken(address _rewardsToken) public {
        require(
            (msg.sender == owner || msg.sender == bribeFactory),
            "addReward: permission is denied!"
        );
        require(!isRewardToken[_rewardsToken], "Reward token already exists");
        isRewardToken[_rewardsToken] = true;
        rewardTokens.push(_rewardsToken);
    }

    function lengthRewardtokens() external view returns (uint256) {
        return rewardTokens.length;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable(address _rewardsToken)
        public
        view
        returns (uint256)
    {
        return
            Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(address _rewardsToken)
        public
        view
        returns (uint256)
    {
        if (_totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(_rewardsToken) -
                rewardData[_rewardsToken].lastUpdateTime) *
                rewardData[_rewardsToken].rewardRate *
                1e18) / _totalSupply);
    }

    function earned(address account, address _rewardsToken)
        public
        view
        returns (uint256)
    {
        return
            ((_balances[account] *
                (rewardPerToken(_rewardsToken) -
                    userRewardPerTokenPaid[account][_rewardsToken])) / 1e18) +
            rewards[account][_rewardsToken];
    }

    function getRewardForDuration(address _rewardsToken)
        external
        view
        returns (uint256)
    {
        return rewardData[_rewardsToken].rewardRate * DURATION;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _deposit(uint256 amount, address voter)
        external
        nonReentrant
        updateReward(voter)
    {
        require(amount > 0, "Cannot stake 0");
        require(msg.sender == gaugeFactory);
        _totalSupply = _totalSupply + amount;
        _balances[voter] = _balances[voter] + amount;
        emit Staked(voter, amount);
    }

    function _withdraw(uint256 amount, address voter)
        public
        nonReentrant
        updateReward(voter)
    {
        require(amount > 0, "Cannot withdraw 0");
        require(msg.sender == gaugeFactory);
        // incase of bribe contract reset in gauge factory
        if (amount <= _balances[voter]) {
            _totalSupply = _totalSupply - amount;
            _balances[voter] = _balances[voter] - amount;
            emit Withdrawn(voter, amount);
        }
    }

    function getRewardForOwnerToOtherOwner(address voter, address receiver)
        public
        nonReentrant
        updateReward(voter)
    {
        if (voter != receiver) {
            require(
                voter == msg.sender || whitelisted[voter][receiver] == true,
                "not owner or whitelisted"
            );
        }

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[voter][_rewardsToken];
            if (reward > 0) {
                rewards[voter][_rewardsToken] = 0;

                uint256 refReward = (reward * referralFee) / 10000;
                uint256 remainingRefReward = refReward;

                IERC20(_rewardsToken).safeTransfer(
                    receiver,
                    reward - refReward
                );
                emit RewardPaid(
                    voter,
                    receiver,
                    _rewardsToken,
                    reward - refReward
                );

                address ref = IReferrals(referralContract).getSponsor(voter);

                uint256 x = 0;
                while (x < refLevelPercent.length && refLevelPercent[x] > 0) {
                    if (ref != IReferrals(referralContract).membersList(0)) {
                        uint256 refFeeAmount = (refReward *
                            refLevelPercent[x]) / 10000;
                        remainingRefReward = remainingRefReward - refFeeAmount;
                        IERC20(_rewardsToken).safeTransfer(ref, refFeeAmount);
                        earnedRefs[ref][_rewardsToken] =
                            earnedRefs[ref][_rewardsToken] +
                            refFeeAmount;
                        emit RefRewardPaid(ref, _rewardsToken, reward);
                        ref = IReferrals(referralContract).getSponsor(ref);
                        x++;
                    } else {
                        x += 30051999;
                    }
                }
                if (remainingRefReward > 0) {
                    IERC20(_rewardsToken).safeTransfer(
                        IGaugeFactory(gaugeFactory).mainRefFeeReceiver(),
                        remainingRefReward
                    );
                }
            }
        }
    }

    function getRewardForOwner(address voter) external {
        getRewardForOwnerToOtherOwner(voter, voter);
    }

    function getReward() external {
        getRewardForOwnerToOtherOwner(msg.sender, msg.sender);
    }

    function notifyRewardAmount(address _rewardsToken, uint256 reward)
        external
        nonReentrant
        updateReward(address(0))
    {
        require(
            reward >= DURATION,
            "reward amount should be greater than DURATION"
        );
        require(isRewardToken[_rewardsToken], "reward token not verified");
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(
            msg.sender,
            address(this),
            reward
        );

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward / DURATION;
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish -
                block.timestamp;
            uint256 leftover = remaining * rewardData[_rewardsToken].rewardRate;
            require(
                reward > leftover,
                "reward amount should be greater than leftover amount"
            ); // to stop griefing attack
            rewardData[_rewardsToken].rewardRate =
                (reward + leftover) /
                DURATION;
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp + DURATION;
        emit RewardAdded(_rewardsToken, reward);
    }

    // set whitlist for other receiver
    function setwhitelisted(address _receiver, bool _whitlist) public {
        whitelisted[msg.sender][_receiver] = _whitlist;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        require(
            rewardData[tokenAddress].lastUpdateTime == 0,
            "Cannot withdraw reward token"
        );
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /* ========== REFERRAL FUNCTIONS ========== */

    // update the referral Variables
    function updateReferral(
        address _referralsContract,
        uint256 _referralFee,
        uint256[] memory _refLevelPercent
    ) public {
        require((msg.sender == gaugeFactory), "!gaugeFactory");
        referralContract = _referralsContract;
        referralFee = _referralFee;
        refLevelPercent = _refLevelPercent;
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        for (uint256 i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token]
                    .rewardPerTokenStored;
            }
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(address indexed rewardToken, uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(
        address indexed user,
        address indexed receiver,
        address indexed rewardsToken,
        uint256 reward
    );
    event Recovered(address indexed token, uint256 amount);
    event RefRewardPaid(
        address indexed user,
        address indexed token,
        uint256 reward
    );
}
