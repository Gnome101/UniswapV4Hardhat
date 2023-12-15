const { ethers } = require("hardhat");
const { assert } = require("chai");
const bigDecimal = require("js-big-decimal");
const { calculateSqrtPriceX96 } = require("../utils/tokenTools");
const { default: Decimal } = require("decimal.js");
const { hexlify } = require("ethers");
describe("Pool Test ", async function () {
  let poolManager;
  let HOG;
  let EPICDAI;

  let uniswapInteract;
  let hookFactory;
  beforeEach(async () => {
    accounts = await ethers.getSigners(); // could also do with getNamedAccounts
    deployer = accounts[0];
    user = accounts[1];
    await deployments.fixture(["Local"]);
    poolManager = await ethers.getContract("PoolManager");
    HOG = await ethers.getContract("HOG");
    EPICDAI = await ethers.getContract("EPICDAI");
    // router = await ethers.getContract("UniswapV4Router");
    // routeFacet = await ethers.getContract("RouterFacet");
    // caller = await ethers.getContract("UniswapV4Caller");
    uniswapInteract = await ethers.getContract("UniswapInteract");
    // hookFactory = await ethers.getContract("UniswapHooksFactory");
  });
  it("can initialze my own pool", async () => {
    //I need key, sqrtPrice, and hookData
    const hook = "0x0000000000000000000000000000000000000000";
    console.log(EPICDAI);
    // console.log(deployer.address);
    const adresses = [EPICDAI.target, HOG.target];
    adresses.sort();
    // console.log(adresses);
    const poolKey = {
      currency0: adresses[0].toString().trim(),
      currency1: adresses[1].toString().trim(),
      fee: "3000",
      tickSpacing: "60",
      hooks: hook,
    };
    const sqrtPrice = calculateSqrtPriceX96(1, 18, 18);
    console.log(sqrtPrice);
    const hookData = hook;
    await poolManager.initialize(poolKey, sqrtPrice.toFixed(), "0x");
    //Modify positon params
    const lowerBound = 0 - 60 * 10;
    const upperBound = 0 + 60 * 10;
    await HOG.mint();
    await EPICDAI.mint();
    await HOG.mint();
    await EPICDAI.mint();
    await HOG.mint();
    await EPICDAI.mint();
    const ModifyPositionParams = {
      tickLower: lowerBound,
      tickUpper: upperBound,
      liquidityDelta: "10000000",
    };

    const brick = "10000000000000000000000000000000"; //100.000
    const liquidtyAmount = "10000000000000000000000";

    // await HOG.approve(router.target, brick.toString());
    // await EPICDAI.approve(router.target, brick.toString());
    await HOG.transfer(uniswapInteract.target, "10000000000000000000000");
    await EPICDAI.transfer(uniswapInteract.target, "10000000000000000000000");
    let timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
    const amount = "1000000000000000000";
    // console.log(uniswapInteract);
    console.log("Adding liquidity...");
    await uniswapInteract.addLiquidity(
      poolKey,
      ModifyPositionParams,
      timeStamp + 100000000
    );
    console.log("Added liquidity!");

    const poolID = await uniswapInteract.getID(poolKey);
    let liq = await poolManager.getLiquidity(poolID);
    // console.log(liq.toString());
    //Add in liquidity finder
    const slot0 = await poolManager.getSlot0(poolID);
    //sqrtPrice,tick, protocalFees, hookFees
    // console.log(slot0.toString());
    const decimalAdj = Decimal.pow(10, 18);
    const token0Amount = new Decimal("10000").times(decimalAdj);
    const token1Amount = new Decimal("10000").times(decimalAdj);
    const liquidity = await uniswapInteract.getLiquidityAmount(
      slot0[1].toString(),
      lowerBound,
      upperBound,
      token0Amount.toFixed(),
      token1Amount.toFixed()
    );
    console.log("Liquidity:", liquidity.toString());
    ModifyPositionParams.liquidityDelta = liquidity.toString();
    await HOG.transfer(uniswapInteract.target, token0Amount.toFixed());
    await EPICDAI.transfer(uniswapInteract.target, token1Amount.toFixed());
    timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
    console.log("Adding liquidity...");

    await uniswapInteract.addLiquidity(
      poolKey,
      ModifyPositionParams,
      timeStamp + 100000000
    );
    liq = await poolManager.getLiquidity(poolID);
    // console.log(liq.toString());
    const swapAmount = new Decimal("90").times(decimalAdj);

    const SwapParams = {
      zeroForOne: true,
      amountSpecified: swapAmount.toFixed(),
      sqrtPriceLimitX96: "4295128740",
    };
    await HOG.transfer(uniswapInteract.target, token0Amount.toFixed());
    //zeroForOne - true - 4295128740
    //zeroForOne - false - 1461446703485210103287273052203988822378723970342
    console.log("Dep", deployer.address);
    await uniswapInteract.swap(poolKey, SwapParams, timeStamp + 100000000);
    console.log("added");
    await HOG.transfer(uniswapInteract.target, token0Amount.toFixed());
    await EPICDAI.transfer(uniswapInteract.target, token1Amount.toFixed());

    await uniswapInteract.donate(
      poolKey,
      "10000000000000000000",
      "10000000000000000000",
      timeStamp + 100000
    );
    //10074110247677932820715
    //10083110247677932820715
    await uniswapInteract.closePosition(
      poolKey,
      lowerBound,
      upperBound,
      timeStamp + 100000000
    );
    //Next is swapper
  });
  it("can initialze my own pool 21", async () => {
    //I need key, sqrtPrice, and hookData

    const hook = await hookFactory.hooks(0);
    const testHook = await ethers.getContractAt("TestHook", hook);

    // console.log(hook);
    //console.log(EPICDAI);
    // console.log(deployer.address);
    const adresses = [EPICDAI.target, HOG.target];
    adresses.sort();
    console.log(adresses);
    const poolKey = {
      currency0: adresses[0].toString().trim(),
      currency1: adresses[1].toString().trim(),
      fee: "100000",
      tickSpacing: "60",
      hooks: hook,
    };
    const sqrtPrice = calculateSqrtPriceX96(1, 18, 18);
    console.log(sqrtPrice);
    const hookData = hook;
    await poolManager.initialize(poolKey, sqrtPrice.toFixed(), "0x");
    //Modify positon params
    const lowerBound = 0 - 60 * 10;
    const upperBound = 0 + 60 * 10;
    await HOG.mint();
    await EPICDAI.mint();
    await HOG.mint();
    await EPICDAI.mint();
    await HOG.mint();
    await EPICDAI.mint();
    const ModifyPositionParams = {
      tickLower: lowerBound,
      tickUpper: upperBound,
      liquidityDelta: "10000000",
    };

    const brick = "10000000000000000000000000000000"; //100.000
    const liquidtyAmount = "10000000000000000000000";

    // await HOG.approve(router.target, brick.toString());
    // await EPICDAI.approve(router.target, brick.toString());
    await HOG.transfer(uniswapInteract.target, "10000000000000000000000");
    await EPICDAI.transfer(uniswapInteract.target, "10000000000000000000000");
    let timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
    const amount = "1000000000000000000";
    // await uniswapInteract.addLiquidity(
    //   poolKey,
    //   ModifyPositionParams,
    //   timeStamp + 100000000
    // );
    const poolID = await uniswapInteract.getID(poolKey);

    //Add in liquidity finder
    const slot0 = await poolManager.getSlot0(poolID);
    //sqrtPrice,tick, protocalFees, hookFees
    // console.log(slot0.toString());
    const decimalAdj = Decimal.pow(10, 18);
    const token0Amount = new Decimal("1000").times(decimalAdj);
    const token1Amount = new Decimal("1000").times(decimalAdj);

    const liquidity = await uniswapInteract.getLiquidityAmount(
      slot0[1].toString(),
      lowerBound,
      upperBound,
      token0Amount.toFixed(),
      token1Amount.toFixed()
    );
    // console.log("Liquidity:", liquidity.toString());
    ModifyPositionParams.liquidityDelta = liquidity.toString();
    await HOG.transfer(uniswapInteract.target, token0Amount.toFixed());
    await EPICDAI.transfer(uniswapInteract.target, token1Amount.toFixed());
    timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
    await uniswapInteract.addLiquidity(
      poolKey,
      ModifyPositionParams,
      timeStamp + 100000000
    );
    let liq = await poolManager.getLiquidity(poolID);
    // console.log(liq.toString());
    const swapAmount = new Decimal("90").times(decimalAdj);

    const SwapParams = {
      zeroForOne: true,
      amountSpecified: swapAmount.toFixed(),
      sqrtPriceLimitX96: "4295128740",
    };
    console.log((await testHook.counter()).toString());

    //zeroForOne - true - 4295128740
    //zeroForOne - false - 1461446703485210103287273052203988822378723970342

    await uniswapInteract.swap(poolKey, SwapParams, timeStamp + 100000000);
    liq = await poolManager.getPosition(
      poolID,
      uniswapInteract.target,
      lowerBound,
      upperBound
    );
    console.log(liq.toString());

    console.log((await testHook.counter()).toString());

    timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
    liq = await poolManager.getPosition(
      poolID,
      uniswapInteract.target,
      lowerBound,
      upperBound
    );
    console.log(liq.toString());
    const daiBalBefore = await EPICDAI.balanceOf(uniswapInteract.target);
    const hogBalBefore = await HOG.balanceOf(uniswapInteract.target);
    await uniswapInteract.donate(
      poolKey,
      "1000000000000000000",
      "1000000000000000000",
      timeStamp + 100000
    );
    const daiBalAfter = await EPICDAI.balanceOf(uniswapInteract.target);
    const hogBalfFter = await HOG.balanceOf(uniswapInteract.target);
    console.log(hogBalBefore.toString(), hogBalfFter.toString());
    console.log(daiBalBefore.toString(), daiBalAfter.toString());
    liq = await poolManager.getPosition(
      poolID,
      uniswapInteract.target,
      lowerBound,
      upperBound
    );
    const slot01 = await poolManager.getSlot0(poolID);
    console.log(slot01.toString());
    console.log(liq.toString());
    console.log("Donated!");
    //Next is sw
  });
});
