const { ethers } = require("hardhat");
const { assert } = require("chai");
const { calculateSqrtPriceX96 } = require("../utils/uniswapTools");
const Big = require("big.js");
const { hexlify } = require("ethers");
const {
  setBlockGasLimit,
} = require("@nomicfoundation/hardhat-network-helpers");
describe("Pool Test ", async function () {
  let poolManager;
  let GNOME;
  let EPICDAI;

  let uniswapInteract;
  let hookFactory;
  beforeEach(async () => {
    accounts = await ethers.getSigners(); // could also do with getNamedAccounts
    deployer = accounts[0];
    user = accounts[1];
    await deployments.fixture(["Local"]);
    poolManager = await ethers.getContract("PoolManager");
    GNOME = await ethers.getContract("GNOME");
    await GNOME.mint();
    await GNOME.mint();
    await GNOME.mint();

    EPICDAI = await ethers.getContract("EPICDAI");
    await EPICDAI.mint();
    await EPICDAI.mint();
    await EPICDAI.mint();

    uniswapInteract = await ethers.getContract("UniswapInteract");
    hookFactory = await ethers.getContract("UniswapHooksFactory");
  });
  it("can initialze my own pool ", async () => {
    //Using no hook for this test
    const hook = "0x0000000000000000000000000000000000000000";

    const addresses = [EPICDAI.target, GNOME.target];
    //Make sure that addresses are sorted!
    addresses.sort();

    //Create the pool key
    const poolKey = {
      currency0: addresses[0].toString().trim(),
      currency1: addresses[1].toString().trim(),
      fee: "3000",
      tickSpacing: "60",
      hooks: hook,
    };
    //Calculate the starting price with (price, decimals in token0, decimals in token1)
    const sqrtPrice = calculateSqrtPriceX96(1, 18, 18);

    await poolManager.initialize(poolKey, sqrtPrice.toFixed(), "0x");
    //Below the bounds are defined for the position
    const lowerBound = 0 - 60 * 10;
    const upperBound = 0 + 60 * 10;

    const ModifyPositionParams = {
      tickLower: lowerBound,
      tickUpper: upperBound,
      liquidityDelta: "10000000",
    };

    let timeStamp = (await ethers.provider.getBlock("latest")).timestamp;

    const poolID = await uniswapInteract.getID(poolKey);
    let liq = await poolManager.getLiquidity(poolID);
    console.log(`The pool is starting with ${liq.toString()} in liquidity`);
    const slot0 = await poolManager.getSlot0(poolID);
    console.log(`Starting tick is ${slot0[1].toString()}`);

    //This is needed to account for the 18 decimals used in ERC20s
    const decimalAdj = new Big(10).pow(18);

    //Below an arbitary amount is set for the token0 and token1 amounts for liquidity
    const token0Amount = new Big("10000").times(decimalAdj);
    const token1Amount = new Big("10000").times(decimalAdj);

    //This is needed to calculate the correct change in liquidity from the token amounts
    const liquidity = await uniswapInteract.getLiquidityAmount(
      slot0[1].toString(),
      lowerBound,
      upperBound,
      token0Amount.toFixed(),
      token1Amount.toFixed()
    );

    ModifyPositionParams.liquidityDelta = liquidity.toString();

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await GNOME.approve(uniswapInteract.target, token0Amount.toFixed());
    await EPICDAI.approve(uniswapInteract.target, token1Amount.toFixed());
    console.log(`Adding liquidity...`);
    //The poolKey is used to identify the pair and the timeStamp + 100 is the deadline
    await uniswapInteract.addLiquidity(
      poolKey,
      ModifyPositionParams,
      timeStamp + 100
    );
    console.log(`Liquidity added!`);
    liq = await poolManager.getLiquidity(poolID);
    console.log(`The pool now has ${liq.toString()} in liquidity`);
    const swapAmount = new Big("10").times(decimalAdj);
    //Below are the neccessary sqrtPriceLimitX96's to set if you want to ignore slippage for a swap

    //zeroForOne - true - 4295128740
    //zeroForOne - false - 1461446703485210103287273052203988822378723970342
    const SwapParams = {
      zeroForOne: true,
      amountSpecified: swapAmount.toFixed(),
      sqrtPriceLimitX96: "4295128740",
    };

    let daiBalBefore = await EPICDAI.balanceOf(deployer.address);
    daiBalBefore = new Big(daiBalBefore.toString());

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await EPICDAI.approve(uniswapInteract.target, swapAmount.toFixed());
    await GNOME.approve(uniswapInteract.target, 0);
    console.log(`Swapping Gnome --> EpicDai`);
    await uniswapInteract.swap(poolKey, SwapParams, timeStamp + 100);
    console.log(`Swap finished!`);

    let daiBalAfter = await EPICDAI.balanceOf(deployer.address);
    daiBalAfter = new Big(daiBalAfter.toString());

    assert.equal(daiBalBefore.toFixed(), daiBalAfter.add(swapAmount).toFixed());

    const token0Donation = new Big("10").times(decimalAdj);
    const token1Donation = new Big("10").times(decimalAdj);

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await EPICDAI.approve(uniswapInteract.target, token0Donation.toFixed());
    await GNOME.approve(uniswapInteract.target, token1Donation.toFixed());

    console.log(`Donating towards the pool...`);
    await uniswapInteract.donate(
      poolKey,
      token0Donation.toFixed(),
      token1Donation.toFixed(),
      timeStamp + 100
    );
    console.log(`Donation finished!`);
    console.log(`Closing position...`);
    await uniswapInteract.closePosition(
      poolKey,
      lowerBound,
      upperBound,
      timeStamp + 100
    );
    console.log(`Position closed`);
    liq = await poolManager.getLiquidity(poolID);

    console.log(`The pool now has ${liq.toString()} in liquidity`);
  });
  it("can initialze my own pool guh", async () => {
    console.log(`\nStarting custom pool test!`);
    //I need key, sqrtPrice, and hookData

    const hook = await hookFactory.hooks(0); //This is the hook created in 01-find-hook.js

    //Sort the tokens
    const addresses = [EPICDAI.target, GNOME.target];
    addresses.sort();

    //Use these flags if you wish to include that fee
    const DYNAMIC_FEE_FLAG = 0x800000;
    const HOOK_SWAP_FEE_FLAG = 0x400000;
    const HOOK_WITHDRAW_FEE_FLAG = 0x200000;

    //All fees are currently included
    const myFees =
      DYNAMIC_FEE_FLAG + HOOK_SWAP_FEE_FLAG + HOOK_WITHDRAW_FEE_FLAG;
    //To set protocl fees it mus be done here

    await poolManager.setProtocolFeeController(hook);

    const poolKey = {
      currency0: addresses[0].toString().trim(),
      currency1: addresses[1].toString().trim(),
      fee: myFees,
      tickSpacing: "60",
      hooks: hook,
    };
    const sqrtPrice = calculateSqrtPriceX96(1, 18, 18);

    await poolManager.initialize(poolKey, sqrtPrice.toFixed(), "0x");
    //Below the bounds are defined for the position
    const lowerBound = 0 - 60 * 10;
    const upperBound = 0 + 60 * 10;

    const ModifyPositionParams = {
      tickLower: lowerBound,
      tickUpper: upperBound,
      liquidityDelta: "10000000",
    };

    let timeStamp = (await ethers.provider.getBlock("latest")).timestamp;

    const poolID = await uniswapInteract.getID(poolKey);
    let liq = await poolManager.getLiquidity(poolID);
    console.log(`The pool is starting with ${liq.toString()} in liquidity`);
    const slot0 = await poolManager.getSlot0(poolID);
    console.log(`Starting tick is ${slot0[1].toString()}`);

    //This is needed to account for the 18 decimals used in ERC20s
    const decimalAdj = new Big(10).pow(18);

    //Below an arbitary amount is set for the token0 and token1 amounts for liquidity
    const token0Amount = new Big("10000").times(decimalAdj);
    const token1Amount = new Big("10000").times(decimalAdj);

    //This is needed to calculate the correct change in liquidity from the token amounts
    const liquidity = await uniswapInteract.getLiquidityAmount(
      slot0[1].toString(),
      lowerBound,
      upperBound,
      token0Amount.toFixed(),
      token1Amount.toFixed()
    );

    ModifyPositionParams.liquidityDelta = liquidity.toString();

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await GNOME.approve(uniswapInteract.target, token0Amount.toFixed());
    await EPICDAI.approve(uniswapInteract.target, token1Amount.toFixed());
    console.log(`Adding liquidity...`);
    //The poolKey is used to identify the pair and the timeStamp + 100 is the deadline
    await uniswapInteract.addLiquidity(
      poolKey,
      ModifyPositionParams,
      timeStamp + 100
    );
    console.log(`Liquidity added!`);
    liq = await poolManager.getLiquidity(poolID);
    console.log(`The pool now has ${liq.toString()} in liquidity\n`);
    const swapAmount = new Big("10").times(decimalAdj);
    //Below are the neccessary sqrtPriceLimitX96's to set if you want to ignore slippage for a swap

    //zeroForOne - true - 4295128740
    //zeroForOne - false - 1461446703485210103287273052203988822378723970342
    const SwapParams = {
      zeroForOne: true,
      amountSpecified: swapAmount.toFixed(),
      sqrtPriceLimitX96: "4295128740",
    };

    let daiBalBefore = await EPICDAI.balanceOf(deployer.address);
    daiBalBefore = new Big(daiBalBefore.toString());

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await EPICDAI.approve(uniswapInteract.target, swapAmount.toFixed());
    await GNOME.approve(uniswapInteract.target, 0);
    console.log(`Swapping Gnome --> EpicDai`);
    await uniswapInteract.swap(poolKey, SwapParams, timeStamp + 100);
    console.log(`Swap finished!\n`);

    let daiBalAfter = await EPICDAI.balanceOf(deployer.address);
    daiBalAfter = new Big(daiBalAfter.toString());

    assert.equal(daiBalBefore.toFixed(), daiBalAfter.add(swapAmount).toFixed());

    const token0Donation = new Big("10").times(decimalAdj);
    const token1Donation = new Big("10").times(decimalAdj);

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await EPICDAI.approve(uniswapInteract.target, token0Donation.toFixed());
    await GNOME.approve(uniswapInteract.target, token1Donation.toFixed());

    console.log(`Donating towards the pool...`);
    await uniswapInteract.donate(
      poolKey,
      token0Donation.toFixed(),
      token1Donation.toFixed(),
      timeStamp + 100
    );
    console.log(`Donation finished!\n`);
    console.log(`Closing position...`);
    await uniswapInteract.closePosition(
      poolKey,
      lowerBound,
      upperBound,
      timeStamp + 100
    );
    console.log(`Position closed`);
    liq = await poolManager.getLiquidity(poolID);

    console.log(`The pool now has ${liq.toString()} in liquidity`);
  });
});
