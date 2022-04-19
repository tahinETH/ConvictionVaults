import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployConvictionBadge, deployVaultFactory, deployTestCollectible } from "../scripts/deploy";


var CBAddress = "0";
var VFAddress = "0";
const mintBadgeFee = 5000000000000000;
var trialNFTContractAddress: any = "0";
var trialNFTTokenId: any = "0";
var testCollectible: any;
var vaultFactory: any;
const lockPeriod = 1;
const doWeMint = true;
var trialNFTTokenId2: number;

describe("VaultInteractions", function () {
    before(async () => {
        CBAddress = await deployConvictionBadge();
        console.log(CBAddress);
        VFAddress = await deployVaultFactory();
        trialNFTContractAddress = (await deployTestCollectible())[0];
        trialNFTTokenId = (await deployTestCollectible())[1];
        console.log(VFAddress);

        testCollectible = await (await ethers.getContractFactory("TestCollectible")).attach(
            `${trialNFTContractAddress}`
        );
        vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
        trialNFTTokenId2 = trialNFTTokenId + 1

    });

    it("Should create a new time-locked vault contract from the vault factory contract.", async () => {
        var signers = await ethers.getSigners();
        const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
        await vaultFactory.createNewVault(true, false, "TrialVault");
        const latestVaultAddress = await vaultFactory.getLatestVault();
        expect(await vaultFactory.getLatestVault()).to.not.eql("0x0000000000000000000000000000000000000000");
        const timeLockedVault = await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress);
        expect(await timeLockedVault.vaultName()).to.eql("TrialVault");
        expect(await timeLockedVault.owner()).to.equal(signers[0].address);

    });

    it("Should check if an authorized account can deposit to the vault", async () => {

        const latestVaultAddress = await vaultFactory.getLatestVault();
        const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
        await testCollectible.approve(latestVaultAddress, trialNFTTokenId);
        console.log("let's check if approved");
        expect(await testCollectible.getApproved(trialNFTTokenId)).to.eql(`${latestVaultAddress}`);


        await timeLockedVault.DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId, lockPeriod, doWeMint, { value: mintBadgeFee });
        const TLVBalance = await timeLockedVault.returnBalance()
        expect(await timeLockedVault.returnBalance()).to.be.above(0);
        expect(await testCollectible.ownerOf(trialNFTTokenId)).to.eql(`${latestVaultAddress}`);
        console.log("passed 2.1")
    });


    it("Should check if an unauthorized account can deposit to the contract", async () => {
        var signers = await ethers.getSigners();

        const latestVaultAddress = await vaultFactory.getLatestVault();
        const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
        await testCollectible.connect(signers[1]).approve(latestVaultAddress, trialNFTTokenId2);
        console.log("let's check if approved");
        expect(await testCollectible.getApproved(trialNFTTokenId2)).to.eql(`${latestVaultAddress}`);
        const TLVBalance = await timeLockedVault.returnBalance()
        await expect((timeLockedVault.connect(signers[1]).DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId2, lockPeriod, doWeMint, { value: mintBadgeFee }))).to.be.revertedWith("You are not authorized to do this!");
        expect(await timeLockedVault.returnBalance()).to.eql(TLVBalance);
        expect(await testCollectible.ownerOf(trialNFTTokenId2)).to.eql(`${signers[1].address}`);
    });

    it("Should authorize an account and check if it can deposit now", async () => {
        var signers = await ethers.getSigners();
        const latestVaultAddress = await vaultFactory.getLatestVault();
        const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
        const TLVBalance = await timeLockedVault.returnBalance()
        await timeLockedVault.authorizeToUse([signers[1].address]);
        console.log("authorized")
        expect(await timeLockedVault.connect(signers[1]).DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId2, lockPeriod, doWeMint, { value: mintBadgeFee })).to.be.ok
        console.log("deposited")
        expect(await timeLockedVault.returnBalance()).to.be.above(TLVBalance);
        expect(await testCollectible.ownerOf(trialNFTTokenId2)).to.eql(`${latestVaultAddress}`);
        console.log("passed 2.2")
    });





    /*     it("Withdraw", async () => {
            const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
            const latestVaultAddress = await vaultFactory.getLatestVault();
            const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
    
            expect(await timeLockedVault.withdraw(trialNFTTokenId))
    
    
        }) */
});
