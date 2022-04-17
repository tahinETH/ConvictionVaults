// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract LockingStorage {
    mapping(address => address[]) internal AddressToVaults;
    address[] internal VaultAddresses;

    //user address to lockedNFTAddress to lockedNFTId to EXP;
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        internal expForSpecificNFT;
    //user address to lockedNFTAddress to to EXP;
    mapping(address => mapping(address => uint256)) internal expForCollection;
}
