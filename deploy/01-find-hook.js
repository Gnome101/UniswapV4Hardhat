const { network } = require("hardhat");
const { verify } = require("../utils/verify");
const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  const owner = deployer;
  //const poolManager = await ethers.getContract("PoolManager");
  const uniswapInteract = await ethers.getContract("UniswapInteract");

  const hookFactory = await ethers.getContract("UniswapHooksFactory");

  //salt is the random number added to the address
  let salt;
  //The final address is the one that matches the correct prefix
  let finalAddress;
  //The desired prefix is set here
  const correctPrefix = 0x8c;

  //The code loops through the salts below
  // - If the address is not found, increase the length of search( e.g i < 2000) and ensure that prefix is possible

  for (let i = 0; i < 1000; i++) {
    salt = ethers.toBeHex(i);
    //console.log(salt);
    salt = ethers.zeroPadValue(salt, 32);

    let expectedAddress = await hookFactory.getPrecomputedHookAddress(
      owner,
      uniswapInteract.target,
      gnosisPoolManagerAddress,
      gnosisMailBox,
      gnosisIGP,
      salt
    );
    finalAddress = expectedAddress;
    //console.log(i, "Address:", expectedAddress);
    expectedAddress = expectedAddress;
    //This console.log() prints all of the generated addresses
    console.log(finalAddress);
    if (_doesAddressStartWith(expectedAddress, correctPrefix)) {
      console.log("This is the correct salt:", salt);
      break;
    }
  }

  function _doesAddressStartWith(_address, _prefix) {
    // console.log(_address.substring(0, 4), ethers.toBeHex(_prefix).toString());
    return _address.substring(0, 4) == ethers.toBeHex(_prefix).toString();
  }

  await hookFactory.deploy(
    uniswapInteract.target,
    gnosisPoolManagerAddress,
    gnosisMailBox,
    gnosisIGP,
    salt
  );
  console.log("Hooks deployed with address:", finalAddress);
  console.log("Chain", chainId);
};
module.exports.tags = ["all", "Need", "Local"];
