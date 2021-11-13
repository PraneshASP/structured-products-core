import { ethers } from "hardhat";

const PRICE_FEED = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

//Change these while depolying!!!
const CONTROLLER = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
const TOKEN_NAME = "Struct LP Token";
const TOKEN_SYMBOL = "SPLP";

async function main() {
  ///Deploy the Struct PLP token
  const StructToken = await ethers.getContractFactory("StructPLP");
  let structToken = await StructToken.deploy(
    CONTROLLER,
    TOKEN_NAME,
    TOKEN_SYMBOL
  );
  await structToken.deployed();

  ///Deploy the Struct Oracle
  const StructOracle = await ethers.getContractFactory("StructOracle");
  let structOracle = await StructOracle.deploy(PRICE_FEED);
  await structOracle.deployed();

  ///Deploy the FixedYieldStrategy Contract
  const FyContract = await ethers.getContractFactory("FixedYieldStrategy");

  const fyStrategy = await FyContract.deploy(
    structToken.address,
    structOracle.address
  );

  await fyStrategy.deployed();
  ///Add the FixedYield Strategy Contract as the Minter
  structToken.addMinter(fyStrategy.address, true);

  console.log("FY Strategy contract deployed", fyStrategy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
