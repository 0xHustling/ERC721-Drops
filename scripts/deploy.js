const hre = require("hardhat");

async function main() {
  console.log("Starting deploy ERC721 Drop...");

  const ERC721Drop = await hre.ethers.getContractFactory(
    "ERC721Drop"
  );

  const erc721Drop = await ERC721Drop.deploy(
    process.env.CONTRACT_NAME,
    process.env.CONTRACT_SYMBOL,
    process.env.CONTRACT_URI,
    process.env.INITIAL_OWNER,
    process.env.FUNDS_RECIPIENT,
    process.env.MAX_SUPPLY,
    process.env.ROYALTY_BPS,
    process.env.MINT_FEE,
    process.env.MINT_FEE_RECIPIENT,
    [
      process.env.PUBLIC_SALE_PRICE,
      process.env.MAX_SALE_PURCHASE_PER_ADDRESS,
      process.env.PUBLIC_SALE_START,
      process.env.PUBLIC_SALE_END,
      process.env.PRE_SALE_START,
      process.env.PRE_SALE_END,
      process.env.PRE_SALE_MERKLE_ROOT,
    ],
    [
      process.env.THUMBNAIL_LINK,
      process.env.COLLECTION_DESCRIPTION,
      process.env.TWITTER_LINK,
      process.env.DISCORD_LINK,
      process.env.INSTAGRAM_LINK,
    ]
  );

  await erc721Drop.deployed();

  console.log(
    `ERC721 drop deployed to: https://goerli.etherscan.io/address/${erc721Drop.address}`
  );

  console.log("Starting deploy ERC721 Drop Factory...");

  const ERC721DropFactory = await hre.ethers.getContractFactory(
    "ERC721DropFactory"
  );

  const erc721DropFactory = await ERC721DropFactory.deploy();

  await erc721DropFactory.deployed(
    process.env.MINT_FEE,
    process.env.MINT_FEE_RECIPIENT
  );

  console.log(
    `ERC721 drop factory deployed to: https://goerli.etherscan.io/address/${erc721DropFactory.address}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
