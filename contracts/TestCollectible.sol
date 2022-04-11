//SPDX-License-Identifier:MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestCollectible is ERC721 {
    uint256 public tokenCounter;

    constructor() ERC721("TestingConviction", "tCNC") {
        tokenCounter = 0;
    }

    function createCollectible() public returns (uint256) {
        uint256 newTokenID = tokenCounter;
        //imported from openzeppelin
        _safeMint(msg.sender, newTokenID);
        tokenCounter = tokenCounter + 1;
        return newTokenID;
    }
}
