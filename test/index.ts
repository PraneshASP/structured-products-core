//import { expect } from "chai";
import { Provider } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { FixedYieldStrategy } from "../typechain";

function BN(number: string) {
  return ethers.utils.parseEther(number.toString());
}

function toNumber(bn: BigNumber) {
  return ethers.utils.formatEther(bn);
}

let owner: Signer, user1: Signer, user2: Signer;
describe("Deposit Test", function () {
  let fyStrategy: FixedYieldStrategy;
  before(async () => {
    [owner, user1, user2] = await ethers.getSigners();
    const StructToken = await ethers.getContractFactory("StructPLP");
    let structToken = await StructToken.deploy("Struct LP Token", "SPLP");
    await structToken.deployed();

    const FY_Contract = await ethers.getContractFactory("FixedYieldStrategy");

    fyStrategy = await FY_Contract.deploy(structToken.address);
    await fyStrategy.deployed();
    structToken.addMinter(fyStrategy.address, true);

    console.log("FY Strategy contract deployed", fyStrategy.address);
  });

  it("should deposit ETH to the curve vault", async () => {
    const tx = await fyStrategy.deposit({ value: BN("1") });
    let receipt = await tx.wait();
    console.log(receipt);
  });
});
