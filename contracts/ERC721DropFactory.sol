// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title ERC721DropFactory
 * @dev The ERC721DropFactory contract allows the deployment of new ERC721Drop contracts,
 * which are non-fungible tokens (NFTs) conforming to the ERC-721 standard. Each ERC721Drop contract
 * represents a unique collection of NFTs with customizable properties.
 * The factory is responsible for creating and managing these individual collections.
 * It inherits from Ownable and Pausable contracts, providing necessary access control features.
 */
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import {ERC721Drop} from "./ERC721Drop.sol";
import {IERC721Drop} from "./interfaces/IERC721Drop.sol";

contract ERC721DropFactory is Ownable, Pausable {
    // Address of the most recently deployed ERC721Drop contract.
    address public lastDeployedContractAddress;
    // Mint fee amount
    uint256 private _mintFeeAmount;
    // Mint fee recipient
    address payable private _mintFeeRecipient;
    // Mapping owner -> deployed contracts
    mapping(address => address[]) public deployedContracts;
    // Deployed contracts count
    uint256 public deployedContractsCount;

    event ERC721DropDeployed(
        string _contractName,
        string _contractSymbol,
        string _contractURI,
        address _initialOwner,
        address _fundsRecipient,
        uint64 _editionSize,
        uint16 _royaltyBPS,
        uint256 _mintFeeAmount,
        address _mintFeeRecipient,
        address _contractAddress
    );

    /**
     * @dev Constructor function.
     */
    constructor(uint256 mintFeeAmount, address payable feeRecipient) {
        _mintFeeAmount = mintFeeAmount;
        _mintFeeRecipient = feeRecipient;
    }

    /**
     * @dev Deploys a new ERC721Drop contract with customizable parameters.
     * @param _contractName The name of the new contract.
     * @param _contractSymbol The symbol of the new contract.
     * @param _contractURI The URI associated with the contract metadata.
     * @param _initialOwner The address of the initial owner of the new contract.
     * @param _fundsRecipient The address where the contract funds will be sent to.
     * @param _editionSize The maximum number of NFTs that can be minted in this collection.
     * @param _royaltyBPS The royalty percentage (basis points) to be paid to the creator on secondary sales.
     * @return erc721DropContract The address of the newly deployed ERC721Drop contract.
     */
    function deployERC721Drop(
        string memory _contractName,
        string memory _contractSymbol,
        string memory _contractURI,
        address _initialOwner,
        address payable _fundsRecipient,
        uint64 _editionSize,
        uint16 _royaltyBPS,
        IERC721Drop.SalesConfiguration memory _salesConfig,
        IERC721Drop.CollectionMeta memory _collectionMeta
    ) external whenNotPaused returns (ERC721Drop erc721DropContract) {
        // Deploy a new ERC721Drop contract with the specified parameters.
        erc721DropContract =
            new ERC721Drop(
                _contractName, 
                _contractSymbol, 
                _contractURI, 
                _initialOwner, 
                _fundsRecipient, 
                _editionSize, 
                _royaltyBPS, 
                _mintFeeAmount, 
                _mintFeeRecipient, 
                _salesConfig, 
                _collectionMeta
            );

        // Add the deployed contract address to the list of deployed contracts.
        deployedContracts[_initialOwner].push(address(erc721DropContract));
        // Increment deployed contracts count
        deployedContractsCount++;

        // Update the last deployed contract address.
        lastDeployedContractAddress = address(erc721DropContract);

        /* Emit an event to notify that a new ERC721Drop contract has been deployed. */
        emit ERC721DropDeployed(
            _contractName,
            _contractSymbol,
            _contractURI,
            _initialOwner,
            _fundsRecipient,
            _editionSize,
            _royaltyBPS,
            _mintFeeAmount,
            _mintFeeRecipient,
            address(erc721DropContract)
        );

        // Return the address of the newly deployed contract.
        return erc721DropContract;
    }

    /**
     * @dev Pauses the contract execution. Can only be called by the contract owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract execution. Can only be called by the contract owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Updates the mint fee recipient. Can only be called by the contract owner.
     */
    function updateFeeRecipient(address payable newMintFeeRecipient) external onlyOwner {
        _mintFeeRecipient = newMintFeeRecipient;
    }

    /**
     * @dev Updates the mint fee amount. Can only be called by the contract owner.
     */
    function updateMintFeeAmount(uint256 newMintFeeAmount) external onlyOwner {
        _mintFeeAmount = newMintFeeAmount;
    }

}
