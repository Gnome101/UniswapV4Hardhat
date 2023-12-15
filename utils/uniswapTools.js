const Big = require("big.js");
const two = new Big(2);
const Q192 = two.pow(192);

function calculateSqrtPriceX96(price, decimalT0, decimalsT1) {
  price = new Big(price);
  const decimalAdj = new Big(10).pow(
    decimalsT1 - decimalT0 == 0 ? 0 : decimalT0 - decimalsT1
  );
  price = price.times(decimalAdj);

  ratioX96 = price.times(Q192);
  sqrtPriceX96 = ratioX96.sqrt().round();
  return sqrtPriceX96;
}

exports.calculateSqrtPriceX96 = calculateSqrtPriceX96;
