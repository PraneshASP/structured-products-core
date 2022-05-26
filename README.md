## Structured Products - Smart contracts <br>
[![built-with openzeppelin](https://img.shields.io/badge/built%20with-OpenZeppelin-3677FF)](https://docs.openzeppelin.com/)

This repository contains the smart contracts source code and configuration for Structured product strategies. The repository uses Hardhat as development environment for compilation, testing and deployment tasks.

### Table of contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Project structure](#project-structure)

### Tools & Frameworks used

- [Hardhat](https://hardhat.org/) - Smart Contract Development Suite
- [OpenZeppelin](https://openzeppelin.com/contracts/) - Battle-tested libraries of smart contracts
- [Chainlink](https://chain.link/) - Decentralized oracle networks for price feeds & more. 
- [Solhint](https://protofire.github.io/solhint/) - Linting Suite
- [Prettier](https://github.com/prettier-solidity/prettier-plugin-solidity) - Automatic Code Formatting
- [Solidity](https://docs.soliditylang.org/en/v0.8.6/) - Smart Contract Programming Language

---

## Introduction

This project contains the Smart contracts for the MVP of Structured products protocol, which provides various options for tokenizing yield-bearing positions & complex derivatives to provide investors & institutions with a simple investment product, tailored to their risk profile. 

We also won the **Top Quality Prize**🏆 at the Chainlink Fall Hackathon 2021 for this project.   

> You can find more details here [https://devpost.com/software/struct-finance](https://devpost.com/software/struct-finance)

## Getting Started

### Prerequisites

The repository is built using hardhat. So it is recommended to install hardhat globally through npm or yarn using the following commands. Also the development of these smart contracts are done in npm version 7.17.0 & NodeJs version 14.16.0

`sudo npm i -g hardhat`

### Installation

Step by step instructions on setting up the project and running it

1. Clone the repository
   `git clone https://github.com/PraneshASP/structured-products-core`
2. Install Dependencies
   `npm install`
3. Compiling Smart Contracts (Auto compiles all .sol file inside contracts directory)
   `npx hardhat compile`
4. Deploying Smart Contracts
   `npx hardhat run ./scripts/deploy.ts --network <network-name>`

   > Network name can be local for local hardhat network. For adding other networks, please configure them in hardhat.config.ts file in the root directory.

   > Name of the smart contracts can be found inside the scripts folders in the root directory.

5. Verification of Smart Contracts
   `npx hardhat verify <deployed-contract-address> --network <network-name> --constructor-args arguments/<contract-name>.argument.ts`

   > Network name can be kovan for kovan testnet and testnet for BSC testnet. For adding other networks, please configure them in hardhat.config.ts file in the root directory.
   > Name of the smart contracts to be verified can be found inside the arguments folders in the root directory.

### Project structure

1. All contract codes, interfaces and utilites imported in the smart contracts can be found at [/contracts](./contracts)
2. All contract interfaces are found at [/contracts/interfaces](./contracts/interfaces).
3. Deployment scripts for deploying the smart contracts can be found at [/scripts](./scripts)

   > These are the codes that have to be created while deploying the smart contracts. Make sure the arguments
   > are appropriate before deployment.

4. Verification arguments are added and stored as .js files inside [/arguments](./arguments)

   > Change these to the deployed contract arguments to successfully verify your contract in explorers. These arguments are the ones that we used in the constructor of the smart contract during their deployment. For verification purpose, we store it here.

All configuration is done in hardhat.config.js & linting configurations are made in `.solhint.json` & `.prettierrc`


### Testing Locally
In order to test the contracts locally, you'll need to run a mainnet-forked hardhat node. This can be done by simply running the `npx hardhat node` command inside the root directory of this project.


