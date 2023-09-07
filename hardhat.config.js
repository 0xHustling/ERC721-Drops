require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-abi-exporter');
require('solidity-docgen');
require('solidity-coverage');
require('dotenv').config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
    },
  },
  networks: {
      goerli: {
        chainId: 5,
        url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [process.env.WALLET_PK]
      },
      mainnet: {
        chainId: 1,
        url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [process.env.WALLET_PK]
      },
      matic: {
        chainId: 137,
        url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [process.env.WALLET_PK]
      },
      optimism: {
        chainId: 10,
        url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [process.env.WALLET_PK]
      },
      arbitrum: {
        chainId: 42161,
        url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [process.env.WALLET_PK]
      },
      arbitrumgoerli: {
        chainId: 421613,
        url: `https://arbitrum-goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [process.env.WALLET_PK]
      },
      hardhat: {
        forking: {
          url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
          blockNumber: 117114300
        },
        accounts: {
          count: 150,
        },
      }
    },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999,
      },
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
};
