// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IERC721Drop {
    error Access_OnlyAdmin();
    error Access_MissingRoleOrAdmin(bytes32 role);
    error Access_WithdrawNotAllowed();
    error Withdraw_FundsSendFailure();
    error MintFee_FundsSendFailure();
    error ExternalMetadataRenderer_CallFailed();
    error OperatorNotAllowed(address operator);
    error MarketFilterDAOAddressNotSupportedForChain();
    error RemoteOperatorFilterRegistryCallFailed();
    error Sale_Inactive();
    error Presale_Inactive();
    error Presale_MerkleNotApproved();
    error Purchase_WrongPrice(uint256 correctPrice);
    error Mint_SoldOut();
    error Purchase_TooManyForAddress();
    error Presale_TooManyForAddress();
    error Setup_RoyaltyPercentageTooHigh(uint16 maxRoyaltyBPS);
    error Admin_InvalidUpgradeAddress(address proposedAddress);
    error Admin_UnableToFinalizeNotOpenEdition();
    error InvalidMintSchedule();

    event MintFeePayout(uint256 mintFeeAmount, address mintFeeRecipient, bool success);
    event Sale(
        address indexed to, uint256 indexed quantity, uint256 indexed pricePerToken, uint256 firstPurchasedTokenId
    );
    event MintComment(
        address indexed sender, address indexed tokenContract, uint256 indexed tokenId, uint256 quantity, string comment
    );
    event SalesConfigChanged(address indexed changedBy);
    event CollectionMetaChanged(        
        string thumbnailLink,
        string collectionDescription,
        string twitterLink,
        string discordLink,
        string instagramLink);
    event FundsRecipientChanged(address indexed newAddress, address indexed changedBy);
    event FundsWithdrawn(
        address indexed withdrawnBy,
        address indexed withdrawnTo,
        uint256 amount,
        address feeRecipient,
        uint256 feeAmount
    );
    event FundsReceived(address indexed source, uint256 amount);
    event OpenMintFinalized(address indexed sender, uint256 numberOfMints);

    struct Configuration {
        uint64 editionSize;
        uint16 royaltyBPS;
        address payable fundsRecipient;
    }

    struct SalesConfiguration {
        uint104 publicSalePrice;
        uint32 maxSalePurchasePerAddress;
        uint64 publicSaleStart;
        uint64 publicSaleEnd;
        uint64 presaleStart;
        uint64 presaleEnd;
        bytes32 presaleMerkleRoot;
    }

    struct SaleDetails {
        bool publicSaleActive;
        bool presaleActive;
        uint256 publicSalePrice;
        uint64 publicSaleStart;
        uint64 publicSaleEnd;
        uint64 presaleStart;
        uint64 presaleEnd;
        bytes32 presaleMerkleRoot;
        uint256 maxSalePurchasePerAddress;
        uint256 totalMinted;
        uint256 maxSupply;
    }

    struct AddressMintDetails {
        uint256 totalMints;
        uint256 presaleMints;
        uint256 publicMints;
    }

    struct CollectionMeta {
        string thumbnailLink;
        string collectionDescription;
        string twitterLink;
        string discordLink;
        string instagramLink;
    }

    function setCollectionMeta(
        string memory thumbnailLink,
        string memory collectionDescription,
        string memory twitterLink,
        string memory discordLink,
        string memory instagramLink
    ) external;

    function setSaleConfiguration(
        uint104 publicSalePrice,
        uint32 maxSalePurchasePerAddress,
        uint64 publicSaleStart,
        uint64 publicSaleEnd,
        uint64 presaleStart,
        uint64 presaleEnd,
        bytes32 presaleMerkleRoot
    ) external;

    function purchase(uint256 quantity) external payable returns (uint256);

    function purchasePresale(uint256 quantity, uint256 maxQuantity, uint256 pricePerToken, bytes32[] memory merkleProof)
        external
        payable
        returns (uint256);

    function saleDetails() external view returns (SaleDetails memory);

    function mintedPerAddress(address minter) external view returns (AddressMintDetails memory);

    function adminMint(address to, uint256 quantity) external returns (uint256);

    function adminMintAirdrop(address[] memory to) external returns (uint256);

    function isAdmin(address user) external view returns (bool);
}
