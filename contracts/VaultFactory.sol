// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./TimeLockedVault.sol";
import {IConvictionBadge} from "../interfaces/IConvictionBadge.sol";

/**
 * A factory for creating vault contracts.
 * - Users can:
 *   # Spin up new vaults for their NFTs. All the TimeLockedVaults
 *   # generated through this contract can get rewarded with conviction badges.
 *
 **/

contract VaultFactory {
    IConvictionBadge convictionBadge;
    address convictionBadgeAddress;
    address[] public VaultAddresses;
    address public owner;
    uint256 public mintBadgeFee;
    mapping(address => Vaults[]) public AddressToVaults;
    event Received(address, uint256);
    event VaultCreation(address _newVault, address _newVaultOwner);
    event vaultFactoryContractChange(address _newvaultFactoryContract);
    struct Vaults {
        address VaultOwner;
        address VaultAddress;
    }

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
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only owner of the contract can change this."
        );
        _;
    }

    /**
     * @notice Creates a new TimeLockedVault and adds it to the permission list on Conviction Badge contract.
     * @param restrictionState Determines if locking and withdrawing are open to everyone or needs manual authorization.
     * @param vaultNAme Name of the new vault.
     **/
    function createNewVault(bool restrictionState, string memory vaultName)
        public
        returns (address)
    {
        Vaults memory currentVault;

        TimeLockedVault Vault = new TimeLockedVault(
            msg.sender,
            convictionBadgeAddress,
            _vaultName,
            _restrictionState,
            mintBadgeFee
        );
        emit VaultCreation(address(Vault), msg.sender);
        addNewTLVToConviction(address(Vault));

        currentVault.VaultOwner = msg.sender;
        currentVault.VaultAddress = address(Vault);
        AddressToVaults[msg.sender].push(currentVault);
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
        convictionBadge.changeVaultFactoryContract(newvaultFactoryContract);
        emit vaultFactoryContractChange(newvaultFactoryContract);
    }

    /**
     * @notice Adds the new time-locked vault to the Conviction Badge authorization.
     */
    function addNewTLVToConviction(address newTLV) internal {
        convictionBadge.setTimeLockedVaults(newTLV);
    }
}
