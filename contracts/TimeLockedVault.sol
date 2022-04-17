// SPDX-License-Identifier: MIT

////

pragma solidity ^0.8.0;

import {ERC721} from "../dependencies/openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "../dependencies/openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IConvictionBadge} from "../interfaces/IConvictionBadge.sol";
import "./ConvictionBadge.sol";

/**
 * A box without hinges, key, or lid, yet golden treasure inside is hid.
 * - Users can:
 *   # Lock their NFTs for one of the four time periods.
 *   # Withdraw it after the lock expiry date.
 *   # Mint Conviction Badges for locking NFTs.
 *   # Can also lock without minting any badges.
 * - This contract needs to be spun up by the VaultFactory contract to mint badges.
 **/

contract TimeLockedVault is IERC721Receiver {
    address public owner;
    address public convictionBadgeAddress;
    address[] public LockerRoom;
    uint256 public mintBadgeFee;
    string public vaultName;
    bool accessRestriction;
    bool nftRestriction;
    IConvictionBadge convictionBadge;

    event DepositNFT(address tokenAddress, uint256 tokenID, uint256 lockperiod);
    event Withdraw(
        address lockerAddress,
        address tokenAddress,
        uint256 tokenID
    );

    struct Vaulted {
        address[] tokenAddresses;
        uint256[] tokenIDs;
        uint256[] lockPeriods;
    }

    mapping(address => Vaulted) private VaultInfo;
    mapping(address => bool) private acceptedCollectionMapping;
    mapping(address => bool) private mappingAuthorizedNFTs;
    mapping(address => bool) private mappingAuthorizedAccounts;

    /**
    @param _owner The address of the vault owner.
    @param _convictionBadgeAddress The address of the conviction badge contract.
    @param _vaultName Name of the vault.
    @param _accessRestriction Determines whether locking and withdrawing are open to everyone or needs manual authorization.
    @param _nftRestriction Determines whether the vault is gated or open to every collection.
     */

    constructor(
        address _owner,
        address _convictionBadgeAddress,
        string memory _vaultName,
        bool _accessRestriction,
        bool _nftRestriction,
        uint256 _mintBadgeFee
    ) {
        vaultName = _vaultName;
        owner = _owner;
        accessRestriction = _accessRestriction;
        nftRestriction = _nftRestriction;
        convictionBadgeAddress = _convictionBadgeAddress;
        convictionBadge = IConvictionBadge(convictionBadgeAddress);
        mintBadgeFee = _mintBadgeFee;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "You are not the owner. Can't perform this function!"
        );
        _;
    }

    modifier authorizedAccounts() {
        if (accessRestriction) {
            require(
                msg.sender == owner || mappingAuthorizedAccounts[msg.sender],
                "You are not authorized to do this!"
            );
            _;
        } else {
            _;
        }
    }

    modifier acceptedCollections(address _lockedNFTAddress) {
        if (nftRestriction) {
            require(
                acceptedCollectionMapping[_lockedNFTAddress] == true,
                "This collection is not allowed in this vault"
            );
            _;
        } else {
            _;
        }
    }

    function acceptCollection(address _lockedNFTAddress) public onlyOwner {
        acceptedCollectionMapping[_lockedNFTAddress] = true;
    }

    function removeCollection(address _lockedNFTAddress) public onlyOwner {
        acceptedCollectionMapping[_lockedNFTAddress] = false;
    }

    /**
     * @notice Changes access authorization
     * @param newAuthorized The address list of new vault participants.
     */

    function authorizeToUse(address[] memory newAuthorized) public onlyOwner {
        require(accessRestriction == true, "This vault is not restricted.");
        for (uint256 i = 0; i < newAuthorized.length; i++) {
            mappingAuthorizedAccounts[newAuthorized[i]] = true;
        }
    }

    /**
     * @notice Remove access authorization
     * @param toBeUnauthorized The address list of vault participants to be removed.
     */

    function removeAuthorization(address[] memory toBeUnauthorized)
        public
        onlyOwner
    {
        require(accessRestriction == true, "This vault is not restricted.");

        for (uint256 i = 0; i < toBeUnauthorized.length; i++) {
            require(mappingAuthorizedAccounts[toBeUnauthorized[i]] = true);
            require(
                VaultInfo[toBeUnauthorized[i]].tokenAddresses.length == 0 &&
                    VaultInfo[toBeUnauthorized[i]].tokenIDs.length == 0 &&
                    VaultInfo[toBeUnauthorized[i]].lockPeriods.length == 0,
                "Already in. Can't remove now."
            );
            mappingAuthorizedAccounts[toBeUnauthorized[i]] = false;
        }
    }

    /**
     * @notice Deposit NFT to the contract for a specific period of time.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     * @param _lockedNFTId Token ID of the locked NFT.
     * @param _lockPeriod Index of an array that indicates the sum of the lock periods of the badge.
     * @param mintState Checks if the locker wants to mint a badge for their lock.
     */

    function DepositAndLockNFT(
        address _lockedNFTAddress,
        uint256 _lockedNFTId,
        uint256 _lockPeriod,
        bool mintState
    )
        public
        payable
        authorizedAccounts
        acceptedCollections(_lockedNFTAddress)
        returns (uint256)
    {
        address vault_accessor = msg.sender;
        require(
            _lockPeriod >= 0 && _lockPeriod < 4,
            "UnlockDate not included in time options!"
        );

        require(
            IERC721(_lockedNFTAddress).ownerOf(_lockedNFTId) == vault_accessor,
            "You don't own the token!"
        );

        if (mintState == true) {
            require(
                msg.value >= mintBadgeFee &&
                    msg.value <= mintBadgeFee + 1000000,
                "You should pay the exact mint fee."
            );
        }

        (address _lockTokenAddress, uint256 _lockTokenId) = _getNFTData(
            _lockedNFTAddress,
            _lockedNFTId
        );

        uint256 lockedUntil = getTimeLock(_lockPeriod);
        IERC721(_lockTokenAddress).safeTransferFrom(
            vault_accessor,
            address(this),
            _lockTokenId
        );
        _updateAfterDeposit(
            vault_accessor,
            _lockTokenAddress,
            _lockTokenId,
            lockedUntil
        );
        _updateEXP(_lockTokenAddress, _lockTokenId, lockedUntil);

        if (mintState == true) {
            uint256 newTokenId = _mintBadge(
                vault_accessor,
                mintState,
                _lockTokenAddress,
                _lockTokenId,
                _lockPeriod
            );
            emit DepositNFT(_lockedNFTAddress, _lockedNFTId, lockedUntil);
            return newTokenId;
        } else {
            emit DepositNFT(_lockedNFTAddress, _lockedNFTId, lockedUntil);
        }
    }

    function _updateEXP(
        address lockedNFTAddress,
        uint256 lockedNFTId,
        uint256 lockedUntil
    ) internal {}

    function returnBalance() public view returns (uint256) {
        return (address(this).balance);
    }

    /**
     * @notice Calculates the unlock date for the lock period
     */

    function getTimeLock(uint256 _lockPeriod) public view returns (uint256) {
        require(
            _lockPeriod >= 0 && _lockPeriod < 4,
            "UnlockDate not included in time options!"
        );
        uint256 unlockDate;
        // THREE MONTHS
        if (_lockPeriod == 0) {
            unlockDate = block.timestamp + 90 days;
        }
        // SIX MONTHS
        else if (_lockPeriod == 1) {
            unlockDate = block.timestamp + 180 days;
        }
        // A YEAR
        else if (_lockPeriod == 2) {
            unlockDate = block.timestamp + 365 days;
        }
        // TWO YEARS
        else if (_lockPeriod == 3) {
            unlockDate = block.timestamp + 730 days;
        }
        return unlockDate;
    }

    function _getNFTData(address _lockedNFTAddress, uint256 _lockedNFTId)
        internal
        view
        returns (address, uint256)
    {
        IERC721 tokenToBeLocked = IERC721(_lockedNFTAddress);
        require(
            tokenToBeLocked.balanceOf(msg.sender) > 0,
            "You don't own any NFTs"
        );
        require(
            msg.sender == tokenToBeLocked.ownerOf(_lockedNFTId),
            "You don't own this NFT!"
        );
        return (_lockedNFTAddress, _lockedNFTId);

        // takes NFT data from the escrow user
    }

    /**
     * @notice Gets the address, id, and lock period for a user's vaulted NFTs
     * @param _user vault accessor
     */
    function getUserInfo(address _user)
        public
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        return (
            VaultInfo[_user].tokenAddresses,
            VaultInfo[_user].tokenIDs,
            VaultInfo[_user].lockPeriods
        );
    }

    /**
     * @notice Allows withdrawing NFTs after the unlock date.
     * @param _lockedNFTAddress Address of the NFT to be withdrew.
     * @param _lockedNFTId Token Id of the NFT to be withdrew.
     */
    function withdraw(address _lockedNFTAddress, uint256 _lockedNFTId)
        external
        authorizedAccounts
    {
        uint256 wenUnlock;
        for (
            uint256 lockedIndex = 0;
            lockedIndex < VaultInfo[msg.sender].lockPeriods.length;
            lockedIndex++
        ) {
            if (
                VaultInfo[msg.sender].tokenAddresses[lockedIndex] ==
                _lockedNFTAddress &&
                VaultInfo[msg.sender].tokenIDs[lockedIndex] == _lockedNFTId
            ) {
                wenUnlock = VaultInfo[msg.sender].lockPeriods[lockedIndex];
                require(
                    block.timestamp >= wenUnlock,
                    "You need to wait until unlock date."
                );
                _withdraw(_lockedNFTAddress, _lockedNFTId, msg.sender);
                _updateAfterWithdrawal(lockedIndex, msg.sender);
            }
        }
    }

    /**
     * @notice Updates the vault info for the user after depositing to the vault
     * by adding token info to the current deposit records.
     * @param vault_accessor Address of the depositor.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     * @param _lockedNFTId Token ID of the locked NFT.
     * @param unlockDate The date the token will be available to withdrawing.
     */
    function _updateAfterDeposit(
        address vault_accessor,
        address _lockedNFTAddress,
        uint256 _lockedNFTId,
        uint256 unlockDate
    ) internal virtual {
        VaultInfo[vault_accessor].tokenAddresses.push(_lockedNFTAddress);
        VaultInfo[vault_accessor].tokenIDs.push(_lockedNFTId);
        VaultInfo[vault_accessor].lockPeriods.push(unlockDate);
        LockerRoom.push(vault_accessor);
    }

    /**
     * @notice Updates the vault info after withdrawing
     * by deleting the token info from the current deposit records.
     * @param index Index of the array to be updated.
     * @param vault_accessor Address of the withdrawer (=depositor).
     */
    function _updateAfterWithdrawal(uint256 index, address vault_accessor)
        internal
    {
        if (index >= VaultInfo[vault_accessor].tokenIDs.length) return;

        for (
            uint256 i = index;
            i < VaultInfo[vault_accessor].tokenIDs.length - 1;
            i++
        ) {
            VaultInfo[vault_accessor].tokenIDs[i] = VaultInfo[vault_accessor]
                .tokenIDs[i + 1];
            VaultInfo[vault_accessor].tokenAddresses[i] = VaultInfo[
                vault_accessor
            ].tokenAddresses[i + 1];
            VaultInfo[vault_accessor].lockPeriods[i] = VaultInfo[vault_accessor]
                .lockPeriods[i + 1];
        }
        VaultInfo[vault_accessor].tokenIDs.pop();
        VaultInfo[vault_accessor].tokenAddresses.pop();
        VaultInfo[vault_accessor].lockPeriods.pop();
    }

    function _withdraw(
        address _lockedNFTAddress,
        uint256 _lockedNFTId,
        address _withdrawer
    ) internal {
        IERC721(_lockedNFTAddress).transferFrom(
            address(this),
            _withdrawer,
            _lockedNFTId
        );
    }

    /**
     * @notice mints a badge in exchange for locking.
     - @param mintee The address of the badge receiver.
     * @param mintState Checks if the locker wants to mint a badge for their lock.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     * @param _lockedNFTId Token ID of the locked NFT.
     * @param _lockPeriod Index of an array that indicates the sum of the lock periods of the badge.
     */

    function _mintBadge(
        address mintee,
        bool mintState,
        address _lockedNFTAddress,
        uint256 _lockedNFTId,
        uint256 _lockPeriod
    ) internal returns (uint256) {
        require(mintState == true, "You didn't want to mint.");

        uint256 newTokenId = convictionBadge.createCollectible(
            mintee,
            _lockPeriod,
            _lockedNFTId,
            _lockedNFTAddress
        );

        return newTokenId;
    }

    function extendLock() external {}

    function reputationUpdatooor() internal virtual {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
