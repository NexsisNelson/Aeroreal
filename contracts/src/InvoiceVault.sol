// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FractionalizerVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title InvoiceVault
 * @notice A specialized vault for tokenizing invoices / receivables.
 *
 *         The model:
 *         1. An SME (small business) has an unpaid invoice from a buyer.
 *         2. They tokenize the invoice into fractions and sell them at a discount.
 *         3. Investors buy fractions at a discount (e.g., 95c on the dollar).
 *         4. At maturity, the buyer pays the invoice.
 *         5. Proceeds are distributed to fraction holders via pull-claim.
 *         6. Investors earn the discount (5%).
 *
 *         Uses a PULL model for proceeds distribution (industry standard):
 *         each holder calls claimProceeds() to withdraw their share.
 */
contract InvoiceVault is FractionalizerVault {

    using SafeERC20 for IERC20;

    // =========================================================
    // INVOICE METADATA
    // =========================================================

    /// The business that issued (sold) the invoice.
    address public smeIssuer;

    /// The company that owes the money on the invoice.
    address public invoiceBuyer;

    /// The face value of the invoice (in stablecoin base units).
    /// e.g., 5_000_000 * 1e18 = $5M invoice.
    uint256 public faceValue;

    /// The discount in basis points.
    /// e.g., 500 = 5% discount. Investors pay 95c on the dollar.
    uint256 public discountBps;

    /// When the invoice was issued (Unix timestamp).
    uint256 public issueDate;

    /// When payment is due (Unix timestamp).
    uint256 public maturityDate;

    /// Whether the invoice has been settled (buyer paid).
    bool public isSettled;

    /// Total amount received on settlement (in stablecoin base units).
    uint256 public totalSettled;

    /// The stablecoin used for settlement. e.g., USDC or cNGN.
    address public settlementToken;

    /// IPFS hash of the invoice PDF (legal document).
    string public invoiceDocumentURI;

    /// The jurisdiction of the buyer. "Nigeria", "Kenya", "Global", etc.
    string public buyerJurisdiction;

    // =========================================================
    // CLAIM TRACKING (Pull Model)
    // =========================================================

    /// How much each investor has already claimed.
    mapping(address => uint256) public claimed;

    /// Total amount claimed so far across all investors.
    uint256 public totalClaimed;

    // =========================================================
    // EVENTS
    // =========================================================

    event InvoiceMetadataSet(
        address indexed smeIssuer,
        address indexed invoiceBuyer,
        uint256 faceValue,
        uint256 discountBps,
        uint256 maturityDate,
        address settlementToken
    );

    event InvoiceSettled(uint256 amountReceived, uint256 timestamp);
    event ProceedsClaimed(address indexed investor, uint256 amount);

    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    /**
     * @param _nftContract The invoice "certificate" NFT contract.
     * @param _nftTokenId The specific invoice certificate NFT id.
     * @param _totalFractions How many fractions to mint (scaled by 1e18).
     * @param _name Name of the fraction token, e.g. "Invoice #INV-2026-001".
     * @param _symbol Ticker, e.g. "fINV001".
     * @param _smeIssuer The business that issued the invoice.
     * @param _invoiceBuyer The company that owes the money.
     * @param _faceValue Face value (e.g., 5_000_000 * 1e18 for $5M).
     * @param _discountBps Discount in basis points (500 = 5%).
     * @param _maturityDate When payment is due (Unix timestamp).
     * @param _settlementToken The stablecoin used for settlement.
     * @param _invoiceDocumentURI IPFS hash of the invoice PDF.
     * @param _buyerJurisdiction Jurisdiction of the buyer.
     */
    constructor(
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _totalFractions,
        string memory _name,
        string memory _symbol,
        address _smeIssuer,
        address _invoiceBuyer,
        uint256 _faceValue,
        uint256 _discountBps,
        uint256 _maturityDate,
        address _settlementToken,
        string memory _invoiceDocumentURI,
        string memory _buyerJurisdiction
    )
        FractionalizerVault(
            _nftContract,
            _nftTokenId,
            _totalFractions,
            _name,
            _symbol
        )
    {
        require(_maturityDate > block.timestamp, "Maturity must be in the future");
        require(_discountBps <= 5000, "Discount too high (max 50%)");
        require(_faceValue > 0, "Face value must be > 0");

        smeIssuer = _smeIssuer;
        invoiceBuyer = _invoiceBuyer;
        faceValue = _faceValue;
        discountBps = _discountBps;
        issueDate = block.timestamp;
        maturityDate = _maturityDate;
        settlementToken = _settlementToken;
        invoiceDocumentURI = _invoiceDocumentURI;
        buyerJurisdiction = _buyerJurisdiction;

        emit InvoiceMetadataSet(
            _smeIssuer,
            _invoiceBuyer,
            _faceValue,
            _discountBps,
            _maturityDate,
            _settlementToken
        );
    }

    // =========================================================
    // SETTLEMENT (Called when the buyer pays)
    // =========================================================

    /**
     * @notice Called when the invoice is settled. The buyer's payment is
     *         transferred into this vault, and investors can then claim
     *         their share.
     * @param _amountReceived The amount of settlement tokens received.
     * @dev The caller must have approved this contract to spend the tokens
     *      BEFORE calling this function.
     */
    function settleInvoice(uint256 _amountReceived) external onlyOwner {
        require(!isSettled, "Already settled");
        require(_amountReceived > 0, "Amount must be > 0");

        // Pull the funds into the vault.
        IERC20(settlementToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amountReceived
        );

        isSettled = true;
        totalSettled = _amountReceived;

        emit InvoiceSettled(_amountReceived, block.timestamp);
    }

    /**
     * @notice Early settlement — partial payment before maturity.
     *         Useful when the buyer pays early or partially.
     */
    function partialSettlement(uint256 _amountReceived) external onlyOwner {
        require(!isSettled, "Already fully settled");
        require(_amountReceived > 0, "Amount must be > 0");

        IERC20(settlementToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amountReceived
        );

        totalSettled += _amountReceived;

        emit InvoiceSettled(_amountReceived, block.timestamp);
    }

    // =========================================================
    // PROCEEDS CLAIM (Pull Model)
    // =========================================================

    /**
     * @notice Claim your share of the settled invoice proceeds.
     * @dev Each investor calls this to receive their proportional share
     *      of the amount received on settlement.
     */
    function claimProceeds() external nonReentrant {
        require(isSettled, "Invoice not settled yet");
        require(totalSettled > 0, "No proceeds to claim");

        uint256 userBalance = fractionToken.balanceOf(msg.sender);
        require(userBalance > 0, "You have no fractions");

        uint256 totalFractionSupply = fractionToken.totalSupply();
        uint256 userShare = (totalSettled * userBalance) / totalFractionSupply;

        uint256 claimable = userShare - claimed[msg.sender];
        require(claimable > 0, "Nothing to claim");

        claimed[msg.sender] = userShare;
        totalClaimed += claimable;

        IERC20(settlementToken).safeTransfer(msg.sender, claimable);

        emit ProceedsClaimed(msg.sender, claimable);
    }

    // =========================================================
    // READ HELPERS (For the Flutter App)
    // =========================================================

    /// Has the invoice reached its maturity date?
    function isMatured() external view returns (bool) {
        return block.timestamp >= maturityDate;
    }

    /// How many days until maturity? (0 if already matured.)
    function daysUntilMaturity() external view returns (uint256) {
        if (block.timestamp >= maturityDate) return 0;
        return (maturityDate - block.timestamp) / 1 days;
    }

    /// How much can a specific address claim right now?
    function claimableAmount(address _investor) external view returns (uint256) {
        if (!isSettled || totalSettled == 0) return 0;

        uint256 userBalance = fractionToken.balanceOf(_investor);
        if (userBalance == 0) return 0;

        uint256 totalFractionSupply = fractionToken.totalSupply();
        uint256 userShare = (totalSettled * userBalance) / totalFractionSupply;

        return userShare > claimed[_investor] ? userShare - claimed[_investor] : 0;
    }

    /**
     * @notice Get all invoice metadata in a single call.
     */
    function getInvoiceInfo() external view returns (
        address _smeIssuer,
        address _invoiceBuyer,
        uint256 _faceValue,
        uint256 _discountBps,
        uint256 _issueDate,
        uint256 _maturityDate,
        bool _isSettled,
        uint256 _totalSettled,
        address _settlementToken,
        string memory _invoiceDocumentURI,
        string memory _buyerJurisdiction
    ) {
        return (
            smeIssuer,
            invoiceBuyer,
            faceValue,
            discountBps,
            issueDate,
            maturityDate,
            isSettled,
            totalSettled,
            settlementToken,
            invoiceDocumentURI,
            buyerJurisdiction
        );
    }
}
