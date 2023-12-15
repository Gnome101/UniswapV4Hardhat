// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// make sure to update latest 'main' branch on Uniswap repository

import {IPoolManager} from "./Uniswap/V4-Core/interfaces/IPoolManager.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "./Uniswap/V4-Core/types/BalanceDelta.sol";

import {Currency, CurrencyLibrary} from "./Uniswap/V4-Core/types/Currency.sol";
import {PoolIdLibrary, PoolId} from "./Uniswap/V4-Core/types/PoolId.sol";
import {PoolKey} from "./Uniswap/V4-Core/types/PoolId.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Uniswap/Uniswap V3/TickMath.sol";
import "./Uniswap/Uniswap V3/LiquidityAmounts.sol";
error SwapExpired();
error OnlyPoolManager();

using SafeERC20 for IERC20;

//Uncomment below for console logs
import "hardhat/console.sol";

contract UniswapInteract {
    using CurrencyLibrary for Currency;
    IPoolManager public poolManager;
    mapping(uint256 => uint256) actionChoice;
    mapping(uint256 => IPoolManager.ModifyPositionParams) modificaitons;
    mapping(uint256 => uint256[2]) tickBounds;
    mapping(uint256 => IPoolManager.SwapParams) swaps;
    mapping(uint256 => uint256[2]) donations;
    struct position {
        int24 lowerBound;
        int24 upperBound;
        PoolId poolID;
    }
    mapping(address => position[]) positions;

    uint256 modCounter;
    uint256 modSwap;
    uint256 doCount;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function getID(PoolKey memory poolKey) public pure returns (PoolId) {
        return PoolIdLibrary.toId(poolKey);
    }

    function addLiquidity(
        PoolKey calldata poolKey,
        IPoolManager.ModifyPositionParams calldata modifyLiquidtyParams,
        uint256 deadline
    ) public payable returns (uint256, uint256) {
        modificaitons[modCounter] = modifyLiquidtyParams;
        positions[msg.sender].push(
            position(
                modifyLiquidtyParams.tickLower,
                modifyLiquidtyParams.tickUpper,
                getID(poolKey)
            )
        );
        bytes memory res = poolManager.lock(
            abi.encode(msg.sender, poolKey, 0, modCounter, deadline)
        );

        return abi.decode(res, (uint256, uint256));
    }

    function closePosition(
        PoolKey calldata poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 deadline
    ) public payable returns (int128, int128) {
        uint128 liq = poolManager.getLiquidity(
            PoolIdLibrary.toId(poolKey),
            address(this),
            tickLower,
            tickUpper
        );
        modificaitons[modCounter] = IPoolManager.ModifyPositionParams(
            tickLower,
            tickUpper,
            -int128(liq)
        );
        bytes memory res = poolManager.lock(
            abi.encode(msg.sender, poolKey, 0, modCounter, deadline)
        );
        (int128 t0, int128 t1) = abi.decode(res, (int128, int128));
        return (t0, t1);
    }

    function donate(
        PoolKey calldata poolKey,
        uint256 amount0,
        uint256 amount1,
        uint256 deadline
    ) public payable returns (uint256, uint256) {
        donations[doCount] = [amount0, amount1];
        bytes memory res = poolManager.lock(
            abi.encode(msg.sender, poolKey, 2, doCount, deadline)
        );

        return abi.decode(res, (uint256, uint256));
    }

    function swap(
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        uint256 deadline
    ) public payable returns (int256, int256) {
        swaps[modSwap] = swapParams;
        bytes memory res = poolManager.lock(
            abi.encode(msg.sender, poolKey, 1, modSwap, deadline)
        );

        return abi.decode(res, (int256, int256));
    }

    function lockAcquired(
        bytes calldata data
    ) external returns (bytes memory res) {
        if (msg.sender != address(poolManager)) {
            revert OnlyPoolManager();
        }

        (
            address user,
            PoolKey memory poolKey,
            uint256 action,
            uint256 counter,
            uint256 deadline
        ) = abi.decode(data, (address, PoolKey, uint256, uint256, uint256));

        if (block.timestamp > deadline) {
            revert();
        }
        BalanceDelta delta;
        if (action == 0) {
            delta = poolManager.modifyPosition(
                poolKey,
                modificaitons[counter],
                "0x"
            );
            //If the amount is positive, then it is needed for the pool
            //If the amount is negative, then it is given to the user
            if (BalanceDeltaLibrary.amount0(delta) > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency0)),
                    user,
                    address(this),
                    uint256(uint128(BalanceDeltaLibrary.amount0(delta)))
                );
            }
            if (BalanceDeltaLibrary.amount1(delta) > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    user,
                    address(this),
                    uint256(uint128(BalanceDeltaLibrary.amount1(delta)))
                );
            }

            modCounter++;
        }
        if (action == 1) {
            delta = poolManager.swap(poolKey, swaps[counter], "0x");
            if (BalanceDeltaLibrary.amount0(delta) > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency0)),
                    user,
                    address(this),
                    uint256(uint128(BalanceDeltaLibrary.amount0(delta)))
                );
            }
            if (BalanceDeltaLibrary.amount1(delta) > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    user,
                    address(this),
                    uint256(uint128(BalanceDeltaLibrary.amount1(delta)))
                );
            }
            console.log("Swapping here");
            modSwap++;
        }
        if (action == 2) {
            delta = poolManager.donate(
                poolKey,
                donations[counter][0],
                donations[counter][1],
                "0x"
            );
            if (BalanceDeltaLibrary.amount0(delta) > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency0)),
                    user,
                    address(this),
                    uint256(uint128(BalanceDeltaLibrary.amount0(delta)))
                );
            }
            if (BalanceDeltaLibrary.amount1(delta) > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    user,
                    address(this),
                    uint256(uint128(BalanceDeltaLibrary.amount1(delta)))
                );
            }
            doCount++;
        }
        _settleCurrencyBalance(poolKey.currency0, delta.amount0());
        _settleCurrencyBalance(poolKey.currency1, delta.amount1());
        if (action != 2) {
            IERC20(Currency.unwrap(poolKey.currency0)).safeTransfer(
                user,
                IERC20(Currency.unwrap(poolKey.currency0)).balanceOf(
                    (address(this))
                )
            );

            IERC20(Currency.unwrap(poolKey.currency1)).safeTransfer(
                user,
                IERC20(Currency.unwrap(poolKey.currency1)).balanceOf(
                    (address(this))
                )
            );
        }

        res = abi.encode(delta.amount0(), delta.amount1());
        //return new bytes();
    }

    function _settleCurrencyBalance(
        Currency currency,
        int128 deltaAmount
    ) private {
        if (deltaAmount < 0) {
            poolManager.take(currency, address(this), uint128(-deltaAmount));
            return;
        }

        if (currency.isNative()) {
            poolManager.settle{value: uint128(deltaAmount)}(currency);
            return;
        }

        IERC20(Currency.unwrap(currency)).safeTransfer(
            address(poolManager),
            uint128(deltaAmount)
        );
        poolManager.settle(currency);
    }

    function getLiquidityAmount(
        int24 currentTick,
        int24 lowerTick,
        int24 upperTick,
        uint256 amount0,
        uint256 amount1
    ) external pure returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtRatioAtTick(currentTick),
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount0,
                amount1
            );
    }
}
