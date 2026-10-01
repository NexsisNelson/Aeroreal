// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FractionalizerVault.sol";

/**
 * @title CommodityVault
 * @notice A specialized vault for tokenizing physical commodities
 *         (cocoa, sesame, gold, cashew, etc.).
 *
 *         Unlike the base FractionalizerVault (which holds NFTs), this vault
 *         tracks real-world commodity metadata: type, quantity, storage
 *         location, and third-party audit reports.
 *
 *         The base vault's fractionalization mechanics are inherited unchanged.
 */
contract CommodityVault is FractionalizerVault {

    // =========================================================
    // COMMODITY METADATA
    // =========================================================

    /// The type of commodity. e.g. "Cocoa", "Sesame", "Gold", "Cashew".
    string public commodityType;

    /// The quantity in base units. e.g. 100 for 100 kg.
    uint256 public quantity;

    /// The unit of measurement. e.g. "kg", "g", "tonnes", "oz".
    string public unitOfMeasure;

    /// Where the commodity is stored. e.g. "Lagos Free Zone, Warehouse A".
    string public storageLocation;

    /// IPFS hash of the third-party audit report (proves the commodity exists).
    string public auditReportURI;

    /// IPFS hash of the insurance certificate.
    string public insuranceURI;

    /// The custodian responsible for the physical asset.
    string public custodian;

    // =========================================================
    // EVENTS
    // =========================================================

    event CommodityMetadataSet(
        string commodityType,
        uint256 quantity,
        string unitOfMeasure,
        string storageLocation
    );

    event AuditReportUpdated(string auditReportURI);
    event InsuranceUpdated(string insuranceURI);
    event CustodianUpdated(string custodian);

    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    /**
     * @param _nftContract The commodity "certificate" contract (ERC-721)
     *                     representing the physical goods. Each commodity
     *                     batch gets its own certificate NFT.
     * @param _nftTokenId The specific certificate NFT id.
     * @param _totalFractions How many fractions to mint (scaled by 1e18).
     * @param _name Name of the fraction token, e.g. "Fractionalized Cocoa Batch 001".
     * @param _symbol Ticker, e.g. "fCOCOA".
     * @param _commodityType "Cocoa", "Gold", etc.
     * @param _quantity Quantity in base units.
     * @param _unitOfMeasure "kg", "g", "oz", etc.
     * @param _storageLocation Where the commodity is physically held.
     * @param _auditReportURI IPFS hash of the audit report.
     * @param _custodian Name of the custodian.
     */
    constructor(
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _totalFractions,
        string memory _name,
        string memory _symbol,
        string memory _commodityType,
        uint256 _quantity,
        string memory _unitOfMeasure,
        string memory _storageLocation,
        string memory _auditReportURI,
        string memory _custodian
    )
        FractionalizerVault(
            _nftContract,
            _nftTokenId,
            _totalFractions,
            _name,
            _symbol
        )
    {
        commodityType = _commodityType;
        quantity = _quantity;
        unitOfMeasure = _unitOfMeasure;
        storageLocation = _storageLocation;
        auditReportURI = _auditReportURI;
        custodian = _custodian;

        emit CommodityMetadataSet(
            _commodityType,
            _quantity,
            _unitOfMeasure,
            _storageLocation
        );
    }

    // =========================================================
    // METADATA UPDATES (Owner Only)
    // =========================================================

    /// Update the audit report (new audit completed).
    function updateAuditReport(string memory _auditReportURI) external onlyOwner {
        auditReportURI = _auditReportURI;
        emit AuditReportUpdated(_auditReportURI);
    }

    /// Update the insurance certificate.
    function updateInsurance(string memory _insuranceURI) external onlyOwner {
        insuranceURI = _insuranceURI;
        emit InsuranceUpdated(_insuranceURI);
    }

    /// Update the custodian (if the commodity moves to a new vault).
    function updateCustodian(string memory _custodian) external onlyOwner {
        custodian = _custodian;
        emit CustodianUpdated(_custodian);
    }

    // =========================================================
    // READ HELPERS (For the Flutter App)
    // =========================================================

    /**
     * @notice Get all commodity metadata in a single call.
     *         Saves gas for the frontend.
     */
    function getCommodityInfo() external view returns (
        string memory _commodityType,
        uint256 _quantity,
        string memory _unitOfMeasure,
        string memory _storageLocation,
        string memory _auditReportURI,
        string memory _insuranceURI,
        string memory _custodian
    ) {
        return (
            commodityType,
            quantity,
            unitOfMeasure,
            storageLocation,
            auditReportURI,
            insuranceURI,
            custodian
        );
    }
}
