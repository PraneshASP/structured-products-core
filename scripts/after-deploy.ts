const fs = require("fs");

const env = require("dotenv").config();
const CONTRACTS_CONFIG_FILE_PATH = "src/utils/ContractEnv/.contractConfig.ts";

/**
 * @name updateContractAddress
 * @description Method for updating contracts addresses after new deploy.
 * @param {String} newAddr
 */
function updateContractAddresses(newAddr: string) {
  fs.writeFileSync(
    `${env.parsed.FRONT_END_REPO_DIR}/${CONTRACTS_CONFIG_FILE_PATH}`,
    `export const fixedYieldAddress: string = "${newAddr}";`
  );
  console.log("Address for FixedYield changed inside Front-end repo:", newAddr);
}

module.exports = {
  updateContractAddresses,
};
