const { ethers } = require("hardhat");
require("dotenv").config({ path: ".env" });

async function main() {

  const NFTPatentContract = await ethers.getContractFactory("NFTPatent");

  // deploy the contract
  const deployedNFTPatentContract = await NFTPatentContract.deploy();

  await deployedNFTPatentContract.deployed();

  // print the address of the deployed contract
  console.log("NFTPatent Contract Address:", deployedNFTPatentContract.address);
}

// Call the main function and catch if there is any error
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });