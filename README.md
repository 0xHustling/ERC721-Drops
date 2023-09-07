# NFT Drops Contracts

The repository contains template NFT Drops contracts and Factory for deployment. The code is a simplified version of [Zora's ERC721 Contracts](https://github.com/ourzora/zora-721-contracts). Credit to [Zora](https://zora.co/).

### Installation

```console
$ yarn
```

### Compile

```console
$ yarn compile
```

This task will compile all smart contracts in the `contracts` directory.
ABI files will be automatically exported in `artifacts` directory.

### Testing

```console
$ yarn test
```

### Code coverage

```console
$ yarn coverage
```

The report will be printed in the console and a static website containing full report will be generated in `coverage` directory.

### Code style

```console
$ yarn prettier
```

### Verify & Publish contract source code

```console
$ npx hardhat  verify --network mainnet $CONTRACT_ADDRESS $CONSTRUCTOR_ARGUMENTS
```
