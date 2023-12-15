// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PoolKey} from "./Uniswap/V4-Core/types/PoolId.sol";
import {IPoolManager} from "./Uniswap/V4-Core/interfaces/IPoolManager.sol";

import "hardhat/console.sol";
import {Currency} from "./Uniswap/V4-Core/types/Currency.sol";

import "./UniswapInteract.sol";
import "./Hooks/BaseHook.sol";
import "./Uniswap/V4-Core/interfaces/IDynamicFeeManager.sol";
import "./Uniswap/V4-Core/interfaces/IHookFeeManager.sol";
import "./Uniswap/V4-Core/interfaces/IProtocolFeeController.sol";

contract MyHook is
    BaseHook,
    IDynamicFeeManager,
    IHookFeeManager,
    IProtocolFeeController
{
    uint256 public count;

    constructor(address _poolManager) BaseHook(IPoolManager(_poolManager)) {}

    function getHookFees(
        PoolKey calldata /* key */
    ) external pure override returns (uint24) {
        console.log("From Hook - Hook Fee Gotten!");
        return 100;
    }

    function protocolFeesForPool(
        PoolKey calldata /* key */
    ) external pure override returns (uint24) {
        console.log("From Hook - Protocol Fee Gotten!");
        return 10;
        //Must be greater than  4(MIN_PROTOCOL_FEE_DENOMINATOR)
        //General bounds are between 4 and 63 because a modulus is taken at 64
    }

    function getFee(
        address /* sender */,
        PoolKey calldata /* key */
    ) external pure override returns (uint24) {
        console.log("From Hook - Fee Gotten!");
        return 10_000;
    }

    function beforeInitialize(
        address /* sender */,
        PoolKey calldata /* key */,
        uint160 /* sqrtPriceX96 */,
        bytes calldata /*hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - Pool is about to be initialized!");

        return this.beforeInitialize.selector;
    }

    function afterInitialize(
        address /* sender */,
        PoolKey calldata /* key */,
        uint160 /* sqrtPriceX96 */,
        int24 /*tick*/,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - Pool was just initialized!");
        return this.afterInitialize.selector;
    }

    function beforeModifyPosition(
        address /* sender */,
        PoolKey calldata /* key */,
        IPoolManager.ModifyPositionParams calldata /* params*/,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - A modificaiton will occur!");
        return this.beforeModifyPosition.selector;
    }

    function afterModifyPosition(
        address /* sender */,
        PoolKey calldata /* key */,
        IPoolManager.ModifyPositionParams calldata /* params*/,
        BalanceDelta /*delta */,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - Pool was just modified");
        return this.afterModifyPosition.selector;
    }

    function beforeSwap(
        address /*  sender */,
        PoolKey calldata /* key */,
        IPoolManager.SwapParams calldata /* params*/,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - A swap is about to occur!");
        return this.beforeSwap.selector;
    }

    function afterSwap(
        address /* sender */,
        PoolKey calldata /* key */,
        IPoolManager.SwapParams calldata /* params*/,
        BalanceDelta /* delta */,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - A swap just occurred!");
        return this.afterSwap.selector;
    }

    function beforeDonate(
        address /* sender */,
        PoolKey calldata /* key */,
        uint256 /* amount0 */,
        uint256 /* amount1 */,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - A donation is about to be made");
        return this.beforeDonate.selector;
    }

    function afterDonate(
        address /* sender */,
        PoolKey calldata /* key */,
        uint256 /* amount0 */,
        uint256 /* amount1 */,
        bytes calldata /* hookData */
    ) external pure override returns (bytes4) {
        console.log("From Hook - A donation was just made");
        return this.afterDonate.selector;
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        //Upon changing this, one must also change the prefix in 01-find-hook.js
        //In case - https://www.rapidtables.com/convert/number/binary-to-decimal.html
        return
            Hooks.Calls({
                beforeInitialize: true, //10000000
                afterInitialize: true, //01000000
                beforeModifyPosition: true, //00100000
                afterModifyPosition: true, //00010000
                beforeSwap: true, //00001000
                afterSwap: true, //00000100
                beforeDonate: true, //00000010
                afterDonate: true //00000001
            });
    }

    receive() external payable {}
}
