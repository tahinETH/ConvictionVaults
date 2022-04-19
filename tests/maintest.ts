import { expect } from "chai";
import chai from "chai";
import { defaultAccounts, solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { deployConvictionBadge, deployVaultFactory, deployTestCollectible } from "../scripts/deploy";
chai.use(solidity);

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
        console.log("passed 1")




    });

    it("Should check if an authorized account can deposit to the vault", async () => {
        var signers = await ethers.getSigners();
        const latestVaultAddress = await vaultFactory.getLatestVault();
        const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
        await testCollectible.approve(latestVaultAddress, trialNFTTokenId);
        console.log("let's check if approved");
        expect(await testCollectible.getApproved(trialNFTTokenId)).to.eql(`${latestVaultAddress}`);


        await timeLockedVault.DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId, lockPeriod, doWeMint, { value: mintBadgeFee });
        const TLVBalance = await timeLockedVault.returnBalance()
        expect(await timeLockedVault.returnBalance()).to.be.above(0);
        expect(await testCollectible.ownerOf(trialNFTTokenId)).to.eql(`${latestVaultAddress}`);


        //check if storage updated properly
        expect((await timeLockedVault.getUserInfo(signers[0].address))[0][0]).to.eql(`${trialNFTContractAddress}`)
        expect((await timeLockedVault.getUserInfo(signers[0].address))[1][0].toNumber()).to.eq(trialNFTTokenId)
        expect((await timeLockedVault.getUserInfo(signers[0].address))[2][0].toNumber()).to.be.above(0)

        const expForNFT = (await vaultFactory.getBasicEXPData(signers[0].address, `${trialNFTContractAddress}`, trialNFTTokenId))[0].toNumber()
        const expForCollection = (await vaultFactory.getBasicEXPData(signers[0].address, `${trialNFTContractAddress}`, trialNFTTokenId))[1].toNumber()
        console.log("experiences : ", expForNFT, expForCollection)

        //check if experience updated properly
        expect((await vaultFactory.getBasicEXPData(signers[0].address, `${trialNFTContractAddress}`, trialNFTTokenId))[0].toNumber()).to.eql(180)
        expect((await vaultFactory.getBasicEXPData(signers[0].address, `${trialNFTContractAddress}`, trialNFTTokenId))[1].toNumber()).to.eql(180)
        console.log("passed 2")
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

        //check if anything got updated
        expect((await timeLockedVault.getUserInfo(signers[1].address))[0][0]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[1][0]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[2][0]).to.be.undefined


        //check the state of experience
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId2))[0].toNumber()).to.eql(0)
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId2))[0].toNumber()).to.eql(0)
        console.log("passed 3")
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

        //check if storage updated properly
        expect((await timeLockedVault.getUserInfo(signers[1].address))[0][0]).to.eql(`${trialNFTContractAddress}`)
        expect((await timeLockedVault.getUserInfo(signers[1].address))[1][0].toNumber()).to.eq(trialNFTTokenId2)
        expect((await timeLockedVault.getUserInfo(signers[1].address))[2][0].toNumber()).to.be.above(0)


        //check if experience updated properly
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId2))[0].toNumber()).to.eql(180)
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId2))[1].toNumber()).to.eql(180)
        console.log("passed 4")
    });

    it("Should try to revome authorization from an account", async () => {
        var signers = await ethers.getSigners();
        const latestVaultAddress = await vaultFactory.getLatestVault();
        const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
        //authorize addr2
        await timeLockedVault.connect(signers[0]).authorizeToUse([signers[2].address, signers[3].address])
        //Addr1(not owner) trying to remove the access of addr2 (not locked any NFT)
        await expect(timeLockedVault.connect(signers[1]).removeAuthorization([signers[2].address])).to.be.revertedWith("You are not the owner. Can't perform this function!")
        //owner removing authorization of addr1 (currently locked an NFT)
        await expect(timeLockedVault.connect(signers[0]).removeAuthorization([signers[1].address])).to.be.revertedWith("Already in. Can't remove now.")
        //owner removing authorization of addr2(not locked any NFT)
        expect(await timeLockedVault.removeAuthorization([signers[2].address])).to.be.ok
        //Owner removing authorization of addr1(locked) and addr2(not locked)
        await expect(timeLockedVault.connect(signers[0]).removeAuthorization([signers[1].address, signers[2].address])).to.be.revertedWith("Already in. Can't remove now.")
        //Owner removing authorization of addr2(not locked) and addr3(not locked)
        expect(await timeLockedVault.connect(signers[0]).removeAuthorization([signers[2].address, signers[3].address])).to.be.ok
        console.log("passed 5")

    })

    it("Should check deposit possibilities", async () => {
        var signers = await ethers.getSigners();
        const latestVaultAddress = await vaultFactory.getLatestVault();
        const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
        const TLVBalance = await timeLockedVault.returnBalance()
        const trialNFTTokenId3 = trialNFTTokenId + 2

        //try to lock without the minting fee
        await expect((timeLockedVault.connect(signers[1]).DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId3, lockPeriod, doWeMint))).to.be.revertedWith("You should pay the exact mint fee.");
        expect((await timeLockedVault.getUserInfo(signers[1].address))[0][1]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[1][1]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[2][1]).to.be.undefined
        console.log("passed 6")




    })



    /*     it("Withdraw", async () => {
            const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
            const latestVaultAddress = await vaultFactory.getLatestVault();
            const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress));
    
            expect(await timeLockedVault.withdraw(trialNFTTokenId))
    
    
        }) */
});
