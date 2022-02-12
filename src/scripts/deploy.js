const { ethers } = require("ethers");

async function main() {
  const Contract = await ethers.getContractFactor("Mira");
  const contract = await Contract.deploy();

  console.log("Contract deployed to: ", contract.address);
}
