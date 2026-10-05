// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./YieldRewardToken.sol";

/**
 * @title MicroYieldStreamer
 * @notice Users stake FractionTokens here to earn Micro Yield (Sprinkles) every second.
 */
contract MicroYieldStreamer is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---- The token users must stake (FractionToken from the Vault) ----
    IERC20 public stakingToken;

    // ---- The token being dripped out as a reward (Sprinkle) ----
    YieldRewardToken public rewardToken;

    // ---- Ownership ----
    address public owner;

    // ---- The magic math variable: Rewards per staked token over time ----
    uint256 public rewardRate; // Rewards dripped per second (global).
    uint256 public lastUpdateTime; // Last time we updated the math.
    uint256 public rewardPerTokenStored; // Accumulated rewards per token.

    // ---- Track what each user is owed ----
    struct UserInfo {
        uint256 amount; // How many FractionTokens they staked.
        uint256 rewardPerTokenPaid; // The global rate when they last updated.
        uint256 rewards; // Their pending Sprinkle rewards.
    }

    mapping(address => UserInfo) public userInfo;

    // ---- Total amount staked by all users ----
    uint256 public totalStaked;

    // ---- Events for the Flutter app ----
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            userInfo[account].rewards = earned(account);
            userInfo[account].rewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @param _stakingToken The FractionToken address.
     * @param _rewardToken The YieldRewardToken address.
     */
    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = YieldRewardToken(_rewardToken);
        owner = msg.sender;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @notice How much reward is generated per single staked token, globally.
     * @dev This is the magic math that makes "micro" yield possible.
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    /**
     * @notice Calculate how much a user has earned so far.
     * @param account The user's wallet address.
     */
    function earned(address account) public view returns (uint256) {
        UserInfo storage user = userInfo[account];
        return user.rewards + ((user.amount * (rewardPerToken() - user.rewardPerTokenPaid)) / 1e18);
    }

    /**
     * @notice Owner sets the drip rate. e.g., 1 token per second.
     * @param _rewardRate The new reward rate.
     */
    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    /**
     * @notice User deposits their FractionTokens to start earning.
     * @param amount How many FractionTokens to stake.
     */
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        totalStaked += amount;
        userInfo[msg.sender].amount += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice User pulls out their FractionTokens.
     */
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(userInfo[msg.sender].amount >= amount, "Not enough staked");

        totalStaked -= amount;
        userInfo[msg.sender].amount -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice User claims their Micro Yield.
     */
    function claimYield() public nonReentrant updateReward(msg.sender) {
        uint256 reward = userInfo[msg.sender].rewards;
        if (reward > 0) {
            userInfo[msg.sender].rewards = 0;
            rewardToken.mint(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @notice Combo: claim rewards and withdraw stake in one transaction.
     */
    function exit() external {
        withdraw(userInfo[msg.sender].amount);
        claimYield();
    }
}
