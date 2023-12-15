// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import "../MyHook.sol";
import {IPoolManager} from "../Uniswap/V4-Core/interfaces/IPoolManager.sol";
import "hardhat/console.sol";

contract UniswapHooksFactory {
    address[] public hooks;

    function deploy(address poolManager, bytes32 salt) external {
        console.log("deploying hooks...");
        hooks.push(address(new MyHook{salt: salt}(poolManager)));
    }

    function getPrecomputedHookAddress(
        address /*owner */,
        address poolManager,
        bytes32 salt
    ) external view returns (address) {
        //Creation code + constructor argument
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(type(MyHook).creationCode, abi.encode(poolManager))
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)
        );
        return address(uint160(uint256(hash)));
    }
}
