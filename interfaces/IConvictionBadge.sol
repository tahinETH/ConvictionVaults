//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

interface IConvictionBadge {
    function setEscrowContractFirstTime(address escrowContract) external;

    function createCollectible(
        address mintee,
        uint256 lockPeriod,
        uint256 lockTokenId,
        address lockTokenAddress
    ) external returns (uint256);

    function setTimeLockedVaults(address timeLockedWallet) external;

    function changeVFContract(address escrowContract)
        external
        returns (address);

    function mergeMint(
        address mintee,
        uint256 lockPeriod,
        uint256 lockedNFTId,
        address lockedNFTAddress
    ) external returns (uint256);

    function getTokenInfoLoP(uint256 tokenId) external view returns (uint256);

    function getTokenInfoLTI(uint256 tokenId) external view returns (uint256);

    function getTokenInfoLTA(uint256 tokenId) external view returns (address);

    function getMergeContract() external view returns (address);
}
