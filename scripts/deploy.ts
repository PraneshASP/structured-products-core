import { ethers } from "hardhat";

async function main() {
  ///Deploy the Struct PLP token
  const StructToken = await ethers.getContractFactory("StructPLP");
  let structToken = await StructToken.deploy("Struct LP Token", "SPLP");
  await structToken.deployed();

  ///Deploy the FixedYieldStrategy Contract
  const FY_Contract = await ethers.getContractFactory("FixedYieldStrategy");

  const fyStrategy = await FY_Contract.deploy(structToken.address);
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
