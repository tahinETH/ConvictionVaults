// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from "../dependencies/openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IConvictionBadge} from "../interfaces/IConvictionBadge.sol";
import "./TimeLockedVault.sol";
import {LockingStorage} from "./LockingStorage.sol";

/**
 * A factory for creating vault contracts.
 * - Users can:
 *   # Spin up new vaults for their NFTs. All the TimeLockedVaults
 *   # generated through this contract can get rewarded with conviction badges.
 *
 **/

contract VaultFactory is LockingStorage {
    IConvictionBadge convictionBadge;
    address convictionBadgeAddress;
    address public owner;
    uint256 public mintBadgeFee;
    address public lockingStorageAddress;
    mapping(address => bool) private TimeLockedVaults;

    event Received(address, uint256);
    event VaultCreation(address _newVault, address _newVaultOwner);
    event vaultFactoryContractChange(address _newvaultFactoryContract);

    /**
     * @param _owner Owner of the vault factory contract.
     * @param _convictionBadgeAddress Address of the conviction badge contract.
     * @param _mintBadgeFee Fee for minting badges.
     */
    constructor(
        address _owner,
        address _convictionBadgeAddress,
        uint256 _mintBadgeFee
    ) {
        mintBadgeFee = _mintBadgeFee;
        owner = _owner;
        convictionBadgeAddress = _convictionBadgeAddress;
        convictionBadge = IConvictionBadge(_convictionBadgeAddress);
        LockingStorage lockingStorage = new LockingStorage();
        lockingStorageAddress = address(lockingStorage);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only owner of the contract can change this."
        );
        _;
    }
    modifier onlyTimeLockedVaults() {
        require(
            TimeLockedVaults[msg.sender] == true,
            "Only a time-locked vault can do this."
        );
        _;
    }

    /**
     * @notice Creates a new TimeLockedVault and adds it to the permission list on Conviction Badge contract.
     * @param accessRestriction Determines if locking and withdrawing are open to everyone or needs manual authorization.
     * @param vaultName Name of the new vault.
     **/
    function createNewVault(
        bool accessRestriction,
        bool nftRestriction,
        string memory vaultName
    ) public returns (address) {
        TimeLockedVault Vault = new TimeLockedVault(
            msg.sender,
            convictionBadgeAddress,
            vaultName,
            accessRestriction,
            nftRestriction,
            mintBadgeFee
        );
        emit VaultCreation(address(Vault), msg.sender);
        _addNewTLVToConviction(address(Vault));
        AddressToVaults[msg.sender].push(address(Vault));
        VaultAddresses.push(address(Vault));

        return address(Vault);
    }

    function getLatestVault() public view returns (address latest_vault) {
        latest_vault = VaultAddresses[VaultAddresses.length - 1];
        return (latest_vault);
    }

    /**
     * @notice Changes which contract is permissioned to mint Conviction Badges.
     * @param newvaultFactoryContract contract address for the new Vault factory.
     */

    function changeVaultFactoryContract(address newvaultFactoryContract)
        public
        onlyOwner
    {
        convictionBadge.changeVFContract(newvaultFactoryContract);
        emit vaultFactoryContractChange(newvaultFactoryContract);
    }

    /**
     * @notice Adds the new time-locked vault to the Conviction Badge authorization.
     */
    function _addNewTLVToConviction(address newTLV) internal {
        convictionBadge.setTimeLockedVaults(newTLV);
        TimeLockedVaults[newTLV] = true;
    }

    function updateEXP(
        address lockedNFTAddress,
        uint256 lockedNFTId,
        uint256 lockedUntil
    ) external onlyTimeLockedVaults {
        expForSpecificNFT[msg.sender][lockedNFTAddress][lockedNFTId] =
            expForSpecificNFT[msg.sender][lockedNFTAddress][lockedNFTId] +
            lockedUntil;
        expForCollection[msg.sender][lockedNFTAddress] =
            expForCollection[msg.sender][lockedNFTAddress] +
            lockedUntil;
    }
}
