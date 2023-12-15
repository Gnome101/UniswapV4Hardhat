// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GNOME is ERC20 {
    constructor() ERC20("GNOME", "GNE") {
        //Uncomment to mint upon deployment
        //_mint(msg.sender, 1000 * 10 ** 18);
    }

    function mint() public {
        _mint(msg.sender, 10000 * 10 ** 18);
    }
}
