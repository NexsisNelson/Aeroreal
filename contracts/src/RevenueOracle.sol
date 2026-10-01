// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RevenueOracle
 * @notice The bridge between off-chain revenue and on-chain yield.
 *
 *         In production, this contract would be called by:
 *         - A Chainlink oracle watching a bank account
 *         - A custom off-chain service processing payments
 *         - A stablecoin payment processor (USDC/cNGN)
 *
 *         For the hackathon, this is a permissioned "mock oracle" that
 *         anyone approved by the owner can call to push revenue.
 *
 *         HOW IT WORKS:
 *         1. Off-chain revenue is collected (rent, invoice repayment, etc.).
 *         2. It is converted to stablecoins (USDC/cNGN).
 *         3. The oracle calls `reportRevenue(vault, amount)` and transfers
 *            the stablecoins into this contract.
 *         4. The oracle then calls `distributeToVault(vault)` to push the
 *            funds to the vault's holders.
 *         5. The MicroYieldStreamer (or a dedicated distributor) picks up
 *            the funds and streams them to stakers.
 *
 *         For MVP simplicity, the oracle holds the funds and emits events.
 *         The Streamer upgrade (Day 5) will connect to this.
 */
contract RevenueOracle is Ownable {

    using SafeERC20 for IERC20;

    // =========================================================
    // STATE
    // =========================================================

    /// The stablecoin used for revenue (USDC, cNGN, etc.).
    IERC20 public stablecoin;

    /// Approved reporters who can call `reportRevenue`.
    mapping(address => bool) public reporters;

    /// Revenue balance held for each vault.
    mapping(address => uint256) public vaultRevenue;

    /// Total revenue reported across all vaults.
    uint256 public totalRevenueReported;

    // =========================================================
    // EVENTS
    // =========================================================

    event ReporterAdded(address indexed reporter);
    event ReporterRemoved(address indexed reporter);
    event RevenueReported(
        address indexed vault,
        uint256 amount,
        string revenueType,
        uint256 timestamp
    );
    event RevenueWithdrawn(
        address indexed vault,
        address indexed recipient,
        uint256 amount
    );

    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    /**
     * @param _stablecoin The stablecoin address (USDC, cNGN, etc.).
     */
    constructor(address _stablecoin) Ownable(msg.sender) {
        require(_stablecoin != address(0), "Invalid stablecoin");
        stablecoin = IERC20(_stablecoin);
    }

    // =========================================================
    // REPORTER MANAGEMENT
    // =========================================================

    modifier onlyReporter() {
        require(reporters[msg.sender] || msg.sender == owner(), "Not a reporter");
        _;
    }

    function addReporter(address _reporter) external onlyOwner {
        require(_reporter != address(0), "Zero address");
        reporters[_reporter] = true;
        emit ReporterAdded(_reporter);
    }

    function removeReporter(address _reporter) external onlyOwner {
        reporters[_reporter] = false;
        emit ReporterRemoved(_reporter);
    }

    // =========================================================
    // REVENUE REPORTING
    // =========================================================

    /**
     * @notice Report revenue for a specific vault.
     * @param _vault The vault address receiving the revenue.
     * @param _amount The revenue amount (in stablecoin base units).
     * @param _revenueType A label for the type of revenue. e.g., "Rent",
     *                     "InvoiceRepayment", "CommoditySale".
     * @dev The caller MUST approve this contract to spend `_amount` BEFORE
     *      calling this function.
     */
    function reportRevenue(
        address _vault,
        uint256 _amount,
        string memory _revenueType
    ) external onlyReporter {
        require(_vault != address(0), "Invalid vault");
        require(_amount > 0, "Amount must be > 0");

        // Pull the funds into this contract.
        stablecoin.safeTransferFrom(msg.sender, address(this), _amount);

        // Track the revenue for the vault.
        vaultRevenue[_vault] += _amount;
        totalRevenueReported += _amount;

        emit RevenueReported(_vault, _amount, _revenueType, block.timestamp);
    }

    /**
     * @notice Withdraw revenue for a vault to a recipient (typically the
     *         MicroYieldStreamer for that vault).
     * @param _vault The vault whose revenue is being withdrawn.
     * @param _recipient The address receiving the funds.
     * @param _amount The amount to withdraw.
     */
    function withdrawRevenue(
        address _vault,
        address _recipient,
        uint256 _amount
    ) external onlyReporter {
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be > 0");
        require(vaultRevenue[_vault] >= _amount, "Insufficient vault revenue");

        vaultRevenue[_vault] -= _amount;
        stablecoin.safeTransfer(_recipient, _amount);

        emit RevenueWithdrawn(_vault, _recipient, _amount);
    }

    // =========================================================
    // READ HELPERS
    // =========================================================

    /// Get the pending revenue for a specific vault.
    function getVaultRevenue(address _vault) external view returns (uint256) {
        return vaultRevenue[_vault];
    }

    /// Get the total revenue reported since deployment.
    function getTotalRevenue() external view returns (uint256) {
        return totalRevenueReported;
    }
}
