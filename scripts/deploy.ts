import { ethers } from "hardhat";

const PRICE_FEED = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

//Change these while depolying!!!
const CONTROLLER = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
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
  console.log("Struct LP Token deployed", structToken.address);

  ///Deploy the Struct Oracle
  const StructOracle = await ethers.getContractFactory("StructOracle");
  let structOracle = await StructOracle.deploy(PRICE_FEED);
  await structOracle.deployed();
  console.log("Struct Oracle deployed", structOracle.address);

  ///Deploy the FixedYieldStrategy Contract
  const FyContract = await ethers.getContractFactory("FixedYieldStrategy");

  const fyStrategy = await FyContract.deploy(
    structToken.address,
    structOracle.address
  );

  await fyStrategy.deployed();
  console.log("FY Strategy contract deployed", fyStrategy.address);

  ///Add the FixedYield Strategy Contract as the Minter
  structToken.addMinter(fyStrategy.address, true);

  console.log("Strategy contract set as SPToken minter");

  ///Deploy the SToken
  const SToken = await ethers.getContractFactory("SToken");
  let sToken = await SToken.deploy("Struct SP Token", "SSP", CONTROLLER);
  await sToken.deployed();
  console.log("Struct LP Token deployed", structToken.address);
  ///Deploy the LendingPool Contract
  const LPContract = await ethers.getContractFactory("LendingPool");

  const lpContract = await LPContract.deploy(
    structToken.address,
    sToken.address
  );

  await lpContract.deployed();
  console.log("Lending Pool contract deployed", lpContract.address);

  ///Add the Lending Pool Contract as the Minter
  sToken.addMinter(lpContract.address, true);

  console.log("Lending Pool contract set as SToken minter");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
