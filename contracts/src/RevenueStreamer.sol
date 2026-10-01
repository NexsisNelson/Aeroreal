// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RevenueStreamer
 * @notice Distributes REAL revenue (stablecoins) to fraction holders.
 *
 *         KEY DIFFERENCE from MicroYieldStreamer:
 *         - MicroYieldStreamer MINTS reward tokens out of thin air.
 *         - RevenueStreamer DISTRIBUTES pre-funded stablecoins from real
 *           cash flows (rent, invoice repayments, commodity sale proceeds).
 *
 *         HOW IT WORKS:
 *         1. Revenue flows into this contract from the RevenueOracle.
 *         2. The owner sets a drip rate (or the contract auto-calculates).
 *         3. Users stake their FractionTokens.
 *         4. Every second, yield accrues based on their share of the stake.
 *         5. Users call claimYield() to receive actual stablecoins.
 *
 *         This is production-grade: yield comes from real revenue, not minting.
 */
contract RevenueStreamer is ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;

    // =========================================================
    // STATE
    // =========================================================

    /// The token users must stake (FractionToken from a Vault).
    IERC20 public stakingToken;

    /// The stablecoin distributed as yield (USDC, cNGN, etc.).
    IERC20 public rewardToken;

    /// The vault this Streamer is tied to.
    address public vault;

    // ---- Reward math (same pattern as MicroYieldStreamer) ----
    uint256 public rewardRate;              // Stablecoins per second (global).
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    // ---- User tracking ----
    struct UserInfo {
        uint256 amount;                     // Staked fractions.
        uint256 rewardPerTokenPaid;
        uint256 rewards;                    // Pending stablecoin yield.
    }

    mapping(address => UserInfo) public userInfo;

    // ---- Totals ----
    uint256 public totalStaked;

    /// Lifetime revenue received (for transparency / dashboards).
    uint256 public lifetimeRevenueReceived;

    /// Lifetime yield claimed by users.
    uint256 public lifetimeYieldClaimed;

    // =========================================================
    // EVENTS
    // =========================================================

    event RevenueReceived(address indexed from, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);

    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    /**
     * @param _stakingToken The FractionToken address.
     * @param _rewardToken The stablecoin address (USDC/cNGN).
     * @param _vault The vault this Streamer serves.
     */
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _vault
    ) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        require(_vault != address(0), "Invalid vault");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        vault = _vault;
        lastUpdateTime = block.timestamp;
    }

    // =========================================================
    // REVENUE RECEIPT
    // =========================================================

    /**
     * @notice Deposit real revenue into the Streamer.
     * @dev Anyone can call this — typically the RevenueOracle or a
     *      designated distributor. The caller must have approved this
     *      contract to spend `_amount` stablecoins.
     * @param _amount The revenue amount (in stablecoin base units).
     */
    function depositRevenue(uint256 _amount) external {
        require(_amount > 0, "Amount must be > 0");

        // Update reward math BEFORE receiving new funds.
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        // Pull the funds in.
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);

        lifetimeRevenueReceived += _amount;

        // Auto-distribute over the next 30 days, OR keep the current rate.
        // If there's no active stream, distribute over 30 days.
        if (rewardRate == 0) {
            // 30 days = 2,592,000 seconds.
            rewardRate = _amount / 30 days;
        } else {
            // Append to the current rate proportionally.
            rewardRate += _amount / 30 days;
        }

        emit RevenueReceived(msg.sender, _amount);
        emit RewardRateUpdated(rewardRate);
    }

    // =========================================================
    // REWARD MATH
    // =========================================================

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        UserInfo storage user = userInfo[account];
        return user.rewards +
            ((user.amount * (rewardPerToken() - user.rewardPerTokenPaid)) / 1e18);
    }

    // =========================================================
    // STAKING
    // =========================================================

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            userInfo[account].rewards = earned(account);
            userInfo[account].rewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        totalStaked += amount;
        userInfo[msg.sender].amount += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(userInfo[msg.sender].amount >= amount, "Not enough staked");

        totalStaked -= amount;
        userInfo[msg.sender].amount -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claimYield() public nonReentrant updateReward(msg.sender) {
        uint256 reward = userInfo[msg.sender].rewards;
        require(reward > 0, "Nothing to claim");

        // Ensure the Streamer has enough stablecoins.
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance >= reward, "Insufficient revenue pool");

        userInfo[msg.sender].rewards = 0;
        lifetimeYieldClaimed += reward;

        rewardToken.safeTransfer(msg.sender, reward);

        emit YieldClaimed(msg.sender, reward);
    }

    function exit() external {
        withdraw(userInfo[msg.sender].amount);
        claimYield();
    }

    // =========================================================
    // VIEWS
    // =========================================================

    function getStreamerInfo() external view returns (
        address _stakingToken,
        address _rewardToken,
        address _vault,
        uint256 _totalStaked,
        uint256 _rewardRate,
        uint256 _lifetimeRevenueReceived,
        uint256 _lifetimeYieldClaimed,
        uint256 _currentPoolBalance
    ) {
        return (
            address(stakingToken),
            address(rewardToken),
            vault,
            totalStaked,
            rewardRate,
            lifetimeRevenueReceived,
            lifetimeYieldClaimed,
            rewardToken.balanceOf(address(this))
        );
    }
}
