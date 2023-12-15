// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import "../../Manager.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import "hardhat/console.sol";

contract UniswapHooksFactory {
    address[] public hooks;

    function deploy(
        address IUniswapInteract,
        address poolManager,
        address IMailbox,
        address IInterchainGasPayMaster,
        bytes32 salt
    ) external {
        console.log("deploying hooks...");
        hooks.push(
            address(
                new Manager{salt: salt}(
                    IUniswapInteract,
                    poolManager,
                    IMailbox,
                    IInterchainGasPayMaster
                )
            )
        );
    }

    function getPrecomputedHookAddress(
        address owner,
        address uniswapInteraction,
        address poolManager,
        address mailBox,
        address igp,
        bytes32 salt
    ) external view returns (address) {
        //Creation code + constructor argument
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(Manager).creationCode,
                abi.encode(uniswapInteraction, poolManager, mailBox, igp)
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)
        );
        return address(uint160(uint256(hash)));
    }
}
