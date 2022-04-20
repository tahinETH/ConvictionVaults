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
var convictionBadge: any
var latestVaultAddress: any
var timeLockedVault: any
var signers: any

describe("VaultInteractions", function () {
    before(async () => {
        signers = await ethers.getSigners();
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
        await vaultFactory.createNewVault(true, false, "TrialVault");
        latestVaultAddress = await vaultFactory.getLatestVault();
        trialNFTTokenId2 = trialNFTTokenId + 1
        convictionBadge = await (await ethers.getContractFactory("ConvictionBadge")).attach(CBAddress)
        timeLockedVault = await (await ethers.getContractFactory("TimeLockedVault")).attach(latestVaultAddress)



    });

    it("Should check if a time-locked vault is created.", async () => {
        expect(await vaultFactory.getLatestVault()).to.not.eql("0x0000000000000000000000000000000000000000")
        expect(await timeLockedVault.vaultName()).to.eql("TrialVault");
        expect(await timeLockedVault.owner()).to.equal(signers[0].address);
        console.log("passed 1")




    });

    it("Should check if an authorized account can deposit to the vault", async () => {

        await testCollectible.approve(latestVaultAddress, trialNFTTokenId);
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

        //check conviction badge status
        expect(await convictionBadge.ownerOf(0)).to.eql(signers[0].address)
        expect((await convictionBadge.getTokenInfo(0))[0]).to.eql(trialNFTContractAddress)
        expect((await convictionBadge.getTokenInfo(0))[1].toNumber()).to.eql(trialNFTTokenId)
        console.log("passed 2")
    });


    it("Should check if an unauthorized account can deposit to the contract", async () => {
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
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId2))[1].toNumber()).to.eql(0)

        console.log("passed 3")
    });

    it("Should authorize an account and check if it can deposit now", async () => {
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

        //check conviction badge status
        expect(await convictionBadge.ownerOf(1)).to.eql(signers[1].address)
        expect((await convictionBadge.getTokenInfo(1))[0]).to.eql(trialNFTContractAddress)
        expect((await convictionBadge.getTokenInfo(1))[1].toNumber()).to.eql(trialNFTTokenId2)
        console.log("passed 4")
    });

    it("Should try to revome authorization from an account", async () => {
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

    it("Should check depositing without fees", async () => {

        await expect((timeLockedVault.connect(signers[1]).DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId + 2, lockPeriod, doWeMint))).to.be.revertedWith("You should pay the exact mint fee.");

        //check if anything got updated
        expect((await timeLockedVault.getUserInfo(signers[1].address))[0][1]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[1][1]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[2][1]).to.be.undefined


        //check the state of experience
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId + 2))[0].toNumber()).to.eql(0)
        expect((await vaultFactory.getBasicEXPData(signers[1].address, `${trialNFTContractAddress}`, trialNFTTokenId + 2))[1].toNumber()).to.eql(180)

        console.log("passed 6")

    })

    it("Should check withdrawing possibilities", async () => {
        //an unauthorized account trying to withdraw the NFT
        await expect((timeLockedVault.connect(signers[4]).withdraw(trialNFTContractAddress, trialNFTTokenId))).to.be.revertedWith("You are not authorized to do this!")
        expect(await testCollectible.ownerOf(0)).to.eql(latestVaultAddress)

        //authorized account trying to withdraw before the unlock date
        await expect((timeLockedVault.connect(signers[1]).withdraw(trialNFTContractAddress, trialNFTTokenId2))).to.be.revertedWith("You need to wait until the unlock date.")
        expect(await testCollectible.ownerOf(1)).to.eql(latestVaultAddress)

        //withdraw someone else's token
        await expect((timeLockedVault.connect(signers[0]).withdraw(trialNFTContractAddress, trialNFTTokenId2))).to.be.revertedWith("No token locked by this address.")
        expect(await testCollectible.ownerOf(1)).to.eql(latestVaultAddress)

        //fastforward the time
        const wenUnlock = (await timeLockedVault.getUserInfo(signers[1].address))[2][0].toNumber()
        console.log("wenunlock:", wenUnlock)
        const sixMonths = 180 * 24 * 60 * 60
        await ethers.provider.send('evm_increaseTime', [sixMonths]);

        //try withdrawing someone else's token after the unlockdate
        await expect((timeLockedVault.connect(signers[0]).withdraw(trialNFTContractAddress, trialNFTTokenId2))).to.be.revertedWith("No token locked by this address.")
        expect(await testCollectible.ownerOf(1)).to.eql(latestVaultAddress)

        //authorized account withdrawing their deposited token after the unlock date
        expect(await timeLockedVault.connect(signers[1]).withdraw(trialNFTContractAddress, trialNFTTokenId2)).to.be.ok
        expect(await testCollectible.ownerOf(1)).to.eql(signers[1].address)

        //// check updates after withdrawal
        expect((await timeLockedVault.getUserInfo(signers[1].address))[0][1]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[1][1]).to.be.undefined
        expect((await timeLockedVault.getUserInfo(signers[1].address))[2][1]).to.be.undefined
        console.log("passed 7")

    });

    it("Should check conviction badge interactions", async () => {
        //change vault factory contract
        expect(await vaultFactory.connect(signers[0]).changeVaultFactoryContract(signers[1].address)).to.be.ok

        //change vault contract to back 
        expect(await convictionBadge.connect(signers[1]).changeVFContract(vaultFactory.address)).to.be.ok

        //try changing vault contract from an authorized account
        await expect((vaultFactory.connect(signers[1]).changeVaultFactoryContract(signers[0].address))).to.be.revertedWith("Only owner of the contract can change this.")

        //try minting directly from the contract
        await expect((convictionBadge.connect(signers[1]).createCollectible(signers[0].address, lockPeriod, trialNFTTokenId + 2, trialNFTContractAddress))).to.be.revertedWith("Caller must be a Time Locked Wallet!")

        //try transfering badges to another account
        await expect((convictionBadge.connect(signers[1]).transferFrom(signers[1].address, signers[0].address, 1))).to.be.revertedWith("Cannot transfer it to another account.")


        console.log("passed 8")

    })

    it("Should check merge interactions ", async () => {

        //deposit the same token two times to get mergeable tokens
        const sixMonths = 180 * 24 * 60 * 60

        await testCollectible.connect(signers[1]).approve(latestVaultAddress, trialNFTTokenId + 2);
        expect(await timeLockedVault.connect(signers[1]).DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId + 2, lockPeriod, doWeMint, { value: mintBadgeFee })).to.be.ok
        await ethers.provider.send('evm_increaseTime', [sixMonths]);

        expect(await timeLockedVault.connect(signers[1]).withdraw(trialNFTContractAddress, trialNFTTokenId + 2)).to.be.ok
        expect(await testCollectible.ownerOf(2)).to.eql(signers[1].address)
        await testCollectible.connect(signers[1]).approve(latestVaultAddress, trialNFTTokenId + 2);

        expect(await timeLockedVault.connect(signers[1]).DepositAndLockNFT(`${trialNFTContractAddress}`, trialNFTTokenId + 2, lockPeriod, doWeMint, { value: mintBadgeFee })).to.be.ok
        await ethers.provider.send('evm_increaseTime', [sixMonths]);
        expect(await timeLockedVault.connect(signers[1]).withdraw(trialNFTContractAddress, trialNFTTokenId + 2)).to.be.ok

        // try merging two different badges
        await expect((convictionBadge.connect(signers[1]).mergeBadges([1, 2]))).to.be.revertedWith("Conviction doesn't belong to the same token!")

        //merge two badges minted for the same NFT
        expect(await convictionBadge.connect(signers[1]).mergeBadges([2, 3])).to.be.ok
        expect(await convictionBadge.ownerOf(4)).to.eql(signers[1].address)
        expect((await convictionBadge.getTokenInfo(4))[2].toNumber()).to.eql(12)




        console.log("passed 9")
    })

});
