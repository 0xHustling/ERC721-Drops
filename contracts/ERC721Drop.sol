// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title ERC721Drop
 * @dev The ERC721Drop contract is an implementation of the ERC721A standard with additional features
 * It allows the creation and management of non-fungible tokens (NFTs)
 * that represent unique digital assets with configurable royalties and sales configurations.
 * The contract is Ownable and utilizes AccessControl for role-based access to certain functions.
 * It also implements the IERC2981 interface for royalty support.
 */
import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {IERC2981, IERC165} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC721Drop} from "./interfaces/IERC721Drop.sol";

contract ERC721Drop is ERC721A, IERC2981, ReentrancyGuard, AccessControl, IERC721Drop, Ownable {
    // Storage variables

    /**
     * @dev Configuration struct to store various contract settings.
     */
    IERC721Drop.Configuration public config;

    /**
     * @dev SalesConfiguration struct to store sales-related settings.
     */
    IERC721Drop.SalesConfiguration public salesConfig;

    /**
     * @dev CollectionMeta struct to store coillection meta data.
     */
    IERC721Drop.CollectionMeta public collectionMeta;

    /**
     * @dev Mapping to keep track of the number of tokens minted per address during the presale period.
     */
    mapping(address => uint256) public presaleMintsByAddress;

    // Constants

    /**
     * @dev Maximum number of tokens that can be minted in a single batch.
     * This is used to prevent excessively large minting operations.
     */
    uint256 internal immutable MAX_MINT_BATCH_SIZE = 8;

    // Roles

    /**
     * @dev Role identifier for the contract minters.
     * MINTER_ROLE allows certain addresses to mint new tokens.
     */
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");

    /**
     * @dev Role identifier for the sales managers.
     * SALES_MANAGER_ROLE allows certain addresses to manage sales-related configurations.
     */
    bytes32 public immutable SALES_MANAGER_ROLE = keccak256("SALES_MANAGER");

    // Immutable Variables

    /**
     * @dev Immutable variables for the minting fee and its recipient.
     */
    uint256 private immutable MINT_FEE;
    address payable private immutable MINT_FEE_RECIPIENT;

    // Constants for royaltyBPS validation

    /**
     * @dev Maximum value for the royaltyBPS (Basis Points) setting, expressed as a percentage (50%).
     */
    uint16 constant MAX_ROYALTY_BPS = 50_00;

    // Internal variables

    /**
     * @dev Base URI for metadata of NFTs.
     */
    string private baseURI;

    // Modifiers

    /**
     * @dev Modifier to restrict access to admin roles.
     */
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert Access_OnlyAdmin();
        }
        _;
    }

    /**
     * @dev Modifier to restrict access to a specific role or admin.
     * @param role The role identifier.
     */
    modifier onlyRoleOrAdmin(bytes32 role) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) && !hasRole(role, _msgSender())) {
            revert Access_MissingRoleOrAdmin(role);
        }
        _;
    }

    /**
     * @dev Modifier to check if the contract can mint the requested quantity of tokens.
     * @param quantity The number of tokens to mint.
     */
    modifier canMintTokens(uint256 quantity) {
        if (quantity + _totalMinted() > config.editionSize) {
            revert Mint_SoldOut();
        }
        _;
    }

    /**
     * @dev Modifier to check if the presale period is active.
     */
    modifier onlyPresaleActive() {
        if (!_presaleActive()) {
            revert Presale_Inactive();
        }
        _;
    }

    /**
     * @dev Modifier to check if the public sale period is active.
     */
    modifier onlyPublicSaleActive() {
        if (!_publicSaleActive()) {
            revert Sale_Inactive();
        }
        _;
    }

    // Functions

    /**
     * @dev Checks if the presale period is currently active.
     * @return true if the presale is active, false otherwise.
     */
    function _presaleActive() internal view returns (bool) {
        return salesConfig.presaleStart <= block.timestamp && salesConfig.presaleEnd > block.timestamp;
    }

    /**
     * @dev Checks if the public sale period is currently active.
     * @return true if the public sale is active, false otherwise.
     */
    function _publicSaleActive() internal view returns (bool) {
        return salesConfig.publicSaleStart <= block.timestamp && salesConfig.publicSaleEnd > block.timestamp;
    }

    /**
     * @dev Returns the starting token ID for this contract.
     * @return The starting token ID (1).
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev Returns the ID of the last minted token.
     * @return The last minted token ID.
     */
    function _lastMintedTokenId() internal view returns (uint256) {
        return _nextTokenId() - 1;
    }

    /**
     * @dev Contract constructor.
     * @param _contractName The name of the ERC-721 contract.
     * @param _contractSymbol The symbol of the ERC-721 contract.
     * @param _contractURI The base URI for metadata of NFTs.
     * @param _initialOwner The address that will be the initial owner of the contract.
     * @param _fundsRecipient The address to receive funds from sales and royalties.
     * @param _editionSize The maximum number of tokens that can be minted.
     * @param _royaltyBPS The royalty percentage (Basis Points) to be paid to the funds recipient on each sale.
     * @param _mintFeeAmount The minting fee amount in wei, payable in addition to the token price.
     * @param _mintFeeRecipient The address to receive the minting fee.
     */
    constructor(
        string memory _contractName,
        string memory _contractSymbol,
        string memory _contractURI,
        address _initialOwner,
        address payable _fundsRecipient,
        uint64 _editionSize,
        uint16 _royaltyBPS,
        uint256 _mintFeeAmount,
        address payable _mintFeeRecipient,
        IERC721Drop.SalesConfiguration memory _salesConfig,
        IERC721Drop.CollectionMeta memory _collectionMeta
    ) ERC721A(_contractName, _contractSymbol) {
        MINT_FEE = _mintFeeAmount;
        MINT_FEE_RECIPIENT = _mintFeeRecipient;

        _setupRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _transferOwnership(_initialOwner);
        baseURI = _contractURI;

        if (config.royaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        config.editionSize = _editionSize;
        config.royaltyBPS = _royaltyBPS;
        config.fundsRecipient = _fundsRecipient;

        // Set Sale Config
        salesConfig.publicSalePrice = _salesConfig.publicSalePrice;
        salesConfig.maxSalePurchasePerAddress = _salesConfig.maxSalePurchasePerAddress;
        salesConfig.publicSaleStart = _salesConfig.publicSaleStart;
        salesConfig.publicSaleEnd = _salesConfig.publicSaleEnd;
        salesConfig.presaleStart = _salesConfig.presaleStart;
        salesConfig.presaleEnd = _salesConfig.presaleEnd;
        salesConfig.presaleMerkleRoot = _salesConfig.presaleMerkleRoot;

        // Set Collection Meta
        collectionMeta.thumbnailLink = _collectionMeta.thumbnailLink;
        collectionMeta.collectionDescription = _collectionMeta.collectionDescription;
        collectionMeta.twitterLink = _collectionMeta.twitterLink;
        collectionMeta.discordLink = _collectionMeta.discordLink;
        collectionMeta.instagramLink = _collectionMeta.instagramLink;
    }

    /**
     * @notice Internal function to get the base URI for the ERC721 token metadata.
     * @return The base URI as a string.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @notice Checks if the given user has the DEFAULT_ADMIN_ROLE.
     * @param user The address of the user to check.
     * @return `true` if the user has the DEFAULT_ADMIN_ROLE, otherwise `false`.
     */
    function isAdmin(address user) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, user);
    }

    /**
     * @notice Burns a specific ERC721 token.
     * @param tokenId The ID of the token to be burned.
     */
    function burn(uint256 tokenId) public {
        _burn(tokenId, true);
    }

    /**
     * @notice Returns the royalty information for a given token and sale price.
     * @param tokenId The ID of the token being sold.
     * @param _salePrice The sale price of the token.
     * @return receiver The address of the royalty recipient.
     * @return royaltyAmount The royalty amount to be paid for the given sale.
     */
    function royaltyInfo(uint256 tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (config.fundsRecipient == address(0)) {
            return (config.fundsRecipient, 0);
        }
        return (config.fundsRecipient, (_salePrice * config.royaltyBPS) / 10_000);
    }

    /**
     * @notice Returns the current sale details of the contract.
     * @return A struct containing the sale details.
     */
    function saleDetails() external view returns (IERC721Drop.SaleDetails memory) {
        return IERC721Drop.SaleDetails({
            publicSaleActive: _publicSaleActive(),
            presaleActive: _presaleActive(),
            publicSalePrice: salesConfig.publicSalePrice,
            publicSaleStart: salesConfig.publicSaleStart,
            publicSaleEnd: salesConfig.publicSaleEnd,
            presaleStart: salesConfig.presaleStart,
            presaleEnd: salesConfig.presaleEnd,
            presaleMerkleRoot: salesConfig.presaleMerkleRoot,
            totalMinted: _totalMinted(),
            maxSupply: config.editionSize,
            maxSalePurchasePerAddress: salesConfig.maxSalePurchasePerAddress
        });
    }

    /**
     * @notice Returns the minting details of an address.
     * @param minter The address for which the minting details are queried.
     * @return A struct containing the minting details.
     */
    function mintedPerAddress(address minter)
        external
        view
        override
        returns (IERC721Drop.AddressMintDetails memory)
    {
        return IERC721Drop.AddressMintDetails({
            presaleMints: presaleMintsByAddress[minter],
            publicMints: _numberMinted(minter) - presaleMintsByAddress[minter],
            totalMints: _numberMinted(minter)
        });
    }

    /**
     * @notice Returns the minting fee for a given quantity of tokens.
     * @param quantity The quantity of tokens being minted.
     * @return recipient The address that will receive the minting fee.
     * @return fee The minting fee amount for the given quantity of tokens.
     */
    function feeForAmount(uint256 quantity) public view returns (address payable recipient, uint256 fee) {
        recipient = MINT_FEE_RECIPIENT;
        fee = MINT_FEE * quantity;
    }

    /**
     * @notice Allows users to purchase tokens from the public sale.
     * @param quantity The quantity of tokens to purchase.
     * @return The ID of the first purchased token.
     */
    function purchase(uint256 quantity) external payable nonReentrant onlyPublicSaleActive returns (uint256) {
        return _handlePurchase(msg.sender, quantity);
    }

    /**
     * @notice Allows users to purchase tokens for another recipient from the public sale with a comment.
     * @param recipient The address of the recipient who will receive the purchased tokens.
     * @param quantity The quantity of tokens to purchase.
     * @return The ID of the first purchased token.
     */
    function purchaseWithRecipient(address recipient, uint256 quantity)
        external
        payable
        nonReentrant
        onlyPublicSaleActive
        returns (uint256)
    {
        return _handlePurchase(recipient, quantity);
    }

    /**
     * @notice Internal function to handle token purchases.
     * @param recipient The address of the recipient who will receive the purchased tokens.
     * @param quantity The quantity of tokens to purchase.
     * @return The ID of the first purchased token.
     */
    function _handlePurchase(address recipient, uint256 quantity) internal returns (uint256) {
        _requireCanMintQuantity(quantity);

        uint256 salePrice = salesConfig.publicSalePrice;

        if (msg.value != (salePrice + MINT_FEE) * quantity) {
            revert Purchase_WrongPrice((salePrice + MINT_FEE) * quantity);
        }

        if (
            salesConfig.maxSalePurchasePerAddress != 0
                && _numberMinted(recipient) + quantity - presaleMintsByAddress[recipient]
                    > salesConfig.maxSalePurchasePerAddress
        ) {
            revert Purchase_TooManyForAddress();
        }

        _mintNFTs(recipient, quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        _payoutFee(quantity);

        emit IERC721Drop.Sale({
            to: recipient,
            quantity: quantity,
            pricePerToken: salePrice,
            firstPurchasedTokenId: firstMintedTokenId
        });

        return firstMintedTokenId;
    }

    /**
     * @notice Internal function to mint NFTs in batches.
     * @param to The address of the recipient who will receive the minted tokens.
     * @param quantity The quantity of tokens to mint.
     */
    function _mintNFTs(address to, uint256 quantity) internal {
        do {
            uint256 toMint = quantity > MAX_MINT_BATCH_SIZE ? MAX_MINT_BATCH_SIZE : quantity;
            _mint({to: to, quantity: toMint});
            quantity -= toMint;
        } while (quantity > 0);
    }

    /**
     * @notice Allows whitelisted users to purchase tokens from the presale.
     * @param quantity The quantity of tokens to purchase.
     * @param maxQuantity The maximum quantity of tokens a user can purchase in the presale.
     * @param pricePerToken The price per token in the presale.
     * @param merkleProof The Merkle proof for the presale whitelist.
     * @return The ID of the first purchased token.
     */
    function purchasePresale(
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof
    ) external payable nonReentrant onlyPresaleActive returns (uint256) {
        return _handlePurchasePresale(quantity, maxQuantity, pricePerToken, merkleProof);
    }

    /**
     * @notice Internal function to handle token purchases during the presale.
     * @param quantity The quantity of tokens to purchase.
     * @param maxQuantity The maximum quantity of tokens a user can purchase in the presale.
     * @param pricePerToken The price per token in the presale.
     * @param merkleProof The Merkle proof for the presale whitelist.
     * @return The ID of the first purchased token.
     */
    function _handlePurchasePresale(
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof
    ) internal returns (uint256) {
        _requireCanMintQuantity(quantity);

        if (
            !MerkleProof.verify(
                merkleProof,
                salesConfig.presaleMerkleRoot,
                keccak256(abi.encode(_msgSender(), maxQuantity, pricePerToken))
            )
        ) {
            revert Presale_MerkleNotApproved();
        }

        if (msg.value != (pricePerToken + MINT_FEE) * quantity) {
            revert Purchase_WrongPrice((pricePerToken + MINT_FEE) * quantity);
        }

        presaleMintsByAddress[_msgSender()] += quantity;
        if (presaleMintsByAddress[_msgSender()] > maxQuantity) {
            revert Presale_TooManyForAddress();
        }

        _mintNFTs(_msgSender(), quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        _payoutFee(quantity);

        emit IERC721Drop.Sale({
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: pricePerToken,
            firstPurchasedTokenId: firstMintedTokenId
        });

        return firstMintedTokenId;
    }

    /**
     * @notice Allows the admin to mint tokens for a recipient.
     * @param recipient The address of the recipient who will receive the minted tokens.
     * @param quantity The quantity of tokens to mint.
     * @return The ID of the last minted token.
     */
    function adminMint(address recipient, uint256 quantity)
        external
        onlyRoleOrAdmin(MINTER_ROLE)
        canMintTokens(quantity)
        returns (uint256)
    {
        _mintNFTs(recipient, quantity);

        return _lastMintedTokenId();
    }

    /**
     * @notice Allows the admin to mint tokens for multiple recipients as an airdrop.
     * @param recipients An array of addresses for recipients who will receive the minted tokens.
     * @return The ID of the last minted token.
     */
    function adminMintAirdrop(address[] calldata recipients)
        external
        override
        onlyRoleOrAdmin(MINTER_ROLE)
        canMintTokens(recipients.length)
        returns (uint256)
    {
        uint256 atId = _nextTokenId();
        uint256 startAt = atId;

        unchecked {
            for (uint256 endAt = atId + recipients.length; atId < endAt; atId++) {
                _mintNFTs(recipients[atId - startAt], 1);
            }
        }
        return _lastMintedTokenId();
    }

    /**
     * @notice Allows the admin to set the sale configuration parameters.
     * @param publicSalePrice The price per token for the public sale.
     * @param maxSalePurchasePerAddress The maximum quantity of tokens a user can purchase in the public sale.
     * @param publicSaleStart The start timestamp of the public sale.
     * @param publicSaleEnd The end timestamp of the public sale.
     * @param presaleStart The start timestamp of the presale.
     * @param presaleEnd The end timestamp of the presale.
     * @param presaleMerkleRoot The Merkle root for the presale whitelist.
     */
    function setSaleConfiguration(
        uint104 publicSalePrice,
        uint32 maxSalePurchasePerAddress,
        uint64 publicSaleStart,
        uint64 publicSaleEnd,
        uint64 presaleStart,
        uint64 presaleEnd,
        bytes32 presaleMerkleRoot
    ) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        salesConfig.publicSalePrice = publicSalePrice;
        salesConfig.maxSalePurchasePerAddress = maxSalePurchasePerAddress;
        salesConfig.publicSaleStart = publicSaleStart;
        salesConfig.publicSaleEnd = publicSaleEnd;
        salesConfig.presaleStart = presaleStart;
        salesConfig.presaleEnd = presaleEnd;
        salesConfig.presaleMerkleRoot = presaleMerkleRoot;

        emit SalesConfigChanged(_msgSender());
    }

    /**
     * @notice Allows the admin to set the collection meta parameters.
     * @param thumbnailLink The collection thumbnail IPFS link.
     * @param collectionDescription The collection description.
     * @param twitterLink The Twitter page of the collection.
     * @param discordLink The Discord channel of the collection.
     * @param instagramLink The Instagram page of the collection.
     */
    function setCollectionMeta(
        string memory thumbnailLink,
        string memory collectionDescription,
        string memory twitterLink,
        string memory discordLink,
        string memory instagramLink
    ) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        collectionMeta.thumbnailLink = thumbnailLink;
        collectionMeta.collectionDescription = collectionDescription;
        collectionMeta.twitterLink = twitterLink;
        collectionMeta.discordLink = discordLink;
        collectionMeta.instagramLink = instagramLink;

        emit CollectionMetaChanged(thumbnailLink, collectionDescription, twitterLink, discordLink, instagramLink);
    }

    /**
     * @notice Allows the admin to set the address that will receive the funds from token sales and royalties.
     * @param newRecipientAddress The address of the new funds recipient.
     */
    function setFundsRecipient(address payable newRecipientAddress) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        config.fundsRecipient = newRecipientAddress;
        emit FundsRecipientChanged(newRecipientAddress, _msgSender());
    }

    /**
     * @notice Allows the admin or sales manager to withdraw the contract's balance to the funds recipient address.
     * @dev Only the admin or sales manager can initiate this operation.
     */
    function withdraw() external nonReentrant {
        address sender = _msgSender();

        uint256 funds = address(this).balance;

        if (
            !hasRole(DEFAULT_ADMIN_ROLE, sender) && !hasRole(SALES_MANAGER_ROLE, sender)
                && sender != config.fundsRecipient
        ) {
            revert Access_WithdrawNotAllowed();
        }

        (bool successFunds,) = config.fundsRecipient.call{value: funds}("");
        if (!successFunds) {
            revert Withdraw_FundsSendFailure();
        }

        emit FundsWithdrawn(_msgSender(), config.fundsRecipient, funds, address(0), 0);
    }

    /**
     * @notice Allows the admin or sales manager to finalize the open edition.
     * @dev The edition size must be set to type(uint64).max for this function to work.
     */
    function finalizeOpenEdition() external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        if (config.editionSize != type(uint64).max) {
            revert Admin_UnableToFinalizeNotOpenEdition();
        }

        config.editionSize = uint64(_totalMinted());
        emit OpenMintFinalized(_msgSender(), config.editionSize);
    }

    /**
     * @notice Internal function to pay out the minting fee.
     * @param quantity The quantity of tokens for which the minting fee is to be paid.
     */
    function _payoutFee(uint256 quantity) internal {
        (, uint256 fee) = feeForAmount(quantity);
        (bool success,) = MINT_FEE_RECIPIENT.call{value: fee}("");
        emit MintFeePayout(fee, MINT_FEE_RECIPIENT, success);
    }

    /**
     * @notice Internal function to check if the contract can mint the given quantity of tokens.
     * @param quantity The quantity of tokens to check for minting.
     */
    function _requireCanMintQuantity(uint256 quantity) internal view {
        if (quantity + _totalMinted() > config.editionSize) {
            revert Mint_SoldOut();
        }
    }

    /**
     * @notice Checks whether the contract supports a given interface.
     * @param interfaceId The interface identifier to check.
     * @return `true` if the contract supports the interface, otherwise `false`.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC721A, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || type(IERC2981).interfaceId == interfaceId
            || bytes4(0x49064906) == interfaceId || type(IERC721Drop).interfaceId == interfaceId;
    }

    /**
     * @notice Fallback function to receive Ether and emit an event.
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}
