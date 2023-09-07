const { expect } = require("chai");
const { waffle, ethers, upgrades, network } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { loadFixture } = waffle;

const IMPERSONATED_SIGNER_ADDRESS =
  "0x80c67432656d59144ceff962e8faf8926599bcf8";

const CONTRACT_NAME = "ERC721 Test";
const CONTRACT_SYMBOL = "ERC721";
const CONTRACT_URI = "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/";
const INITIAL_OWNER = "0x8C553e3dd511482b796e36d122982a98dC8BFA9c";
const FUNDS_RECIPIENT = "0x8C553e3dd511482b796e36d122982a98dC8BFA9c";
const MAX_SUPPLY = "10000";
const ROYALTY_BPS = "250";
const MINT_FEE = "1000000000000000";
const MINT_FEE_RECIPIENT = "0x8C553e3dd511482b796e36d122982a98dC8BFA9c";
const PUBLIC_SALE_PRICE = "10000000000000000";
const MAX_SALE_PURCHASE_PER_ADDRESS = "3";
const PUBLIC_SALE_START = "1690883147";
const PUBLIC_SALE_END = "1690969546";
const PRE_SALE_START = "1690882300";
const PRE_SALE_END = "1690883146";
const PRE_SALE_MERKLE_ROOT =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const THUMBNAIL_LINK = "https://test.com";
const COLLECTION_DESCRIPTION = "Test description";
const TWITTER_LINK = "https://x.com";
const DISCORD_LINK = "https://discord.gg";
const INSTAGRAM_LINK = "https://instagram.com";

describe("ERC721", () => {
  const deployedContracts = async () => {
    [deployer] = await ethers.getSigners();
    const ERC721Drop = await hre.ethers.getContractFactory(
      "ERC721Drop",
      deployer
    );
    const erc721Drop = await ERC721Drop.deploy(
      CONTRACT_NAME,
      CONTRACT_SYMBOL,
      CONTRACT_URI,
      INITIAL_OWNER,
      FUNDS_RECIPIENT,
      MAX_SUPPLY,
      ROYALTY_BPS,
      MINT_FEE,
      MINT_FEE_RECIPIENT,
      [
        PUBLIC_SALE_PRICE,
        MAX_SALE_PURCHASE_PER_ADDRESS,
        PUBLIC_SALE_START,
        PUBLIC_SALE_END,
        PRE_SALE_START,
        PRE_SALE_END,
        PRE_SALE_MERKLE_ROOT,
      ],
      [
        THUMBNAIL_LINK,
        COLLECTION_DESCRIPTION,
        TWITTER_LINK,
        DISCORD_LINK,
        INSTAGRAM_LINK,
      ]
    );

    await erc721Drop.deployed();

    await helpers.impersonateAccount(IMPERSONATED_SIGNER_ADDRESS);
    const impersonatedSigner = await ethers.getSigner(
      IMPERSONATED_SIGNER_ADDRESS
    );

    return {
      erc721Drop,
      impersonatedSigner,
      deployer,
    };
  };

  it("should successfully deploy ERC721 with correct configuration", async () => {
    const { erc721Drop } = await loadFixture(deployedContracts);

    const contractName = await erc721Drop.name();
    const contractSymbol = await erc721Drop.symbol();

    expect(contractName).to.equal(CONTRACT_NAME);
    expect(contractSymbol).to.equal(CONTRACT_SYMBOL);
  });

  it("should successfully purchase NFT in public sale", async () => {
    const { erc721Drop, impersonatedSigner } = await loadFixture(
      deployedContracts
    );

    await erc721Drop
      .connect(impersonatedSigner)
      .purchase(1, { value: "11000000000000000" });

    await expect(
      erc721Drop
        .connect(impersonatedSigner)
        .purchase(1, { value: "11000000000000000" })
    ).to.be.emit(erc721Drop, "Sale");
  });
});
