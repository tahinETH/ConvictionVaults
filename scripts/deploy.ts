// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { defaultAccounts } from "ethereum-waffle";
import { ethers } from "hardhat";

var CBAddress = "0";
var VFAddress = "0";
const mintBadgeFee = 5000000000000000;



async function main() {
  await deployConvictionBadge();
  await deployVaultFactory();
  let [trialNFTContractAddress, trialNFTTokenId] = await deployTestCollectible();
  await deployaTimeLockedVault();
  await initiateTimeLock(trialNFTContractAddress, trialNFTTokenId, 1, true);
}

export async function deployConvictionBadge() {
  const URIS = [
    "https://ipfs.io/ipfs/QmPcsgSK17uPmLU83gEQvHpaUvfgktrqkJ16KRrwGu4MRa?filename=vault-one-month.png",
    "https://ipfs.io/ipfs/QmYZkoq5k9ZaPibGKA5XkYZ74FD3rKafQeLbgFsH2n6BnA?filename=vault-three-months.png",
    "https://ipfs.io/ipfs/QmdJNGUHECbMVSJXcGR5Df22FZaTtKEQpChgdLvVR52wnX?filename=vault-six-months.png",
    "https://ipfs.io/ipfs/QmVhKBQRtmfY2Cwzd9cAhz6o4CFjmu7zVxdFzhUuPb4guQ?filename=vault-one-year.png",
  ]
  const ConvictionBadge = await ethers.getContractFactory("ConvictionBadge");
  const convictionBadge = await ConvictionBadge.deploy("Conviction", "CNV", URIS);


  await convictionBadge.deployed();

  console.log("ConvictionBadge deployed to:", convictionBadge.address);
  CBAddress = convictionBadge.address;
  return (CBAddress);




}

export async function deployVaultFactory() {
  const [owner] = await ethers.getSigners();
  const convictionBadge = await (await ethers.getContractFactory("ConvictionBadge")).attach(CBAddress);
  const VaultFactory = await ethers.getContractFactory("VaultFactory");
  const vaultFactory = await VaultFactory.deploy(owner.address, CBAddress, mintBadgeFee);
  await vaultFactory.deployed();
  console.log("VaultFactory deployed at:", vaultFactory.address)
  const cnvVF = await convictionBadge.getVFcontract()
  console.log("VF of conviction before:", cnvVF)
  VFAddress = vaultFactory.address;
  await convictionBadge.setVFContractFirstTime(VFAddress);
  const cnvVFa = await convictionBadge.getVFcontract()
  console.log("VF of conviction after:", cnvVFa)
  return (VFAddress);
}

async function deployaTimeLockedVault() {
  const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
  await vaultFactory.createNewVault(true, "TrialVault",);
  const latestVaultAddress = await vaultFactory.getLatestVault();
  console.log("A new vault created at:", latestVaultAddress);

  let [trialNFTContractAddress, trialNFTTokenId] = await deployTestCollectible();
  console.log("Address and ID of the NFT to be locked: ", [trialNFTContractAddress, trialNFTTokenId]);
}

export async function deployTestCollectible() {
  const TestCollectible = await ethers.getContractFactory("TestCollectible");
  const testCollectible = await TestCollectible.deploy();
  await testCollectible.deployed();

  await testCollectible.createCollectible();
  const tokenID = await (testCollectible.tokenCounter()) - 1
  return [testCollectible.address, tokenID];

}

async function initiateTimeLock(trialNFTContractAddress: any, trialNFTTokenId: any, lockPeriod: number, doWeMint: boolean) {
  const [owner] = await ethers.getSigners();
  const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
  const latestVaultAddress = await vaultFactory.getLatestVault();
  console.log("The address of the latest vault:", latestVaultAddress);

  const testCollectible = await (await ethers.getContractFactory("TestCollectible")).attach(trialNFTContractAddress);
  await testCollectible.approve(latestVaultAddress, trialNFTTokenId);


  const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
  timeLockedVault.DepositAndLockNFT(trialNFTContractAddress, trialNFTTokenId, lockPeriod, doWeMint, { value: mintBadgeFee });
  const balance = await timeLockedVault.returnBalance();
  console.log("Balance of the contract after locking:", balance);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


