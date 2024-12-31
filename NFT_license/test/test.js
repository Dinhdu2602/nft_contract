const {ethers} = require("hardhat")

const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const {solidity} = require('ethereum-waffle')
const chai = require('chai')
chai.use(solidity)
const { expect } = require("chai");

describe("license", function () {
    async function deploylicense() {

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount1, otherAccount2] = await ethers.getSigners();
        // owner.estimateGas(3500000);

        const License = await ethers.getContractFactory("License_Contract");
        const license = await License.deploy();

        const Fractionalize = await ethers.getContractFactory("FractionalizeNFT");
        const fractionalize = await Fractionalize.deploy(license.address);

        return {license,fractionalize, owner, otherAccount1, otherAccount2};
    }

    describe("Deployment", function () {
            it("Should set the right owner", async function () {
                const {license,owner} = await loadFixture(deploylicense);

                expect(await license.owner()).to.equal(owner.address);
            });
            it("Should return the right next id", async function () {
                const {license,owner} = await loadFixture(deploylicense);

                expect(await license.getNextId()).to.equal(1);
            });
        });
    describe("Fractionalize", function () {
        it("Should be able to fractionalize tokens", async function () {
            const {fractionalize, owner, license} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address, "example");
            await license.connect(owner).approve(fractionalize.address, 1);
            await fractionalize.createFraction("Fractionalized", "FNFT", 1, 100, owner.address);
            expect(await license.ownerOf(1)).to.equal(fractionalize.address);
            const faddress = await fractionalize.getUserFractions(owner.address)
            const fractiontoken = await ethers.getContractFactory("FractionToken");
            const fractiontokenIstance = await fractiontoken.attach(faddress[0]);
            expect(await fractiontokenIstance.balanceOf(owner.address)).to.equal(100);
        })
        it("Should be able to fractionalize and then withdraw tokens", async function () {
            const {fractionalize, owner, license} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address, "example");
            await license.connect(owner).approve(fractionalize.address, 1);
            await fractionalize.createFraction("Fractionalized", "FNFT", 1, 100, owner.address);
            const faddress = await fractionalize.getUserFractions(owner.address)
            const fractiontoken = await ethers.getContractFactory("FractionToken");
            const fractiontokenIstance = await fractiontoken.attach(faddress[0]);
            await fractionalize.withdrawNft(faddress[0]);
            expect(await fractiontokenIstance.balanceOf(owner.address)).to.equal(0);
            expect(await license.ownerOf(1)).to.equal(owner.address);
        })
        it("Should not allow withdraw if not all tokens are passed in", async function () {
            const {fractionalize, owner, license, otherAccount1} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address, "example");
            await license.connect(owner).approve(fractionalize.address, 1);
            await fractionalize.createFraction("Fractionalized", "FNFT", 1, 100, owner.address);
            const faddress = await fractionalize.getUserFractions(owner.address)
            const fractiontoken = await ethers.getContractFactory("FractionToken");
            const fractiontokenIstance = await fractiontoken.attach(faddress[0]);
            await fractiontokenIstance.connect(owner).transfer(otherAccount1.address, 50);
            await expect(fractionalize.withdrawNft(faddress[0])).to.be.revertedWith("You do not own all shares");
        })
        it("Should allow withdraw all the nfts", async function () {
            const {fractionalize, owner, license, otherAccount1} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address, "example");
            await license.connect(owner).mint(owner.address, "example1");
            await license.connect(owner).approve(fractionalize.address, 1);
            await license.connect(owner).approve(fractionalize.address, 2);
            await fractionalize.createFraction("Fractionalized", "FNFT", 1, 100, owner.address);
            await fractionalize.createFraction("Fractionalized", "FNFT", 2, 150, owner.address);
            const faddress = await fractionalize.getUserFractions(owner.address)
            const fractiontoken = await ethers.getContractFactory("FractionToken");
            const fractiontokenIstance1 = await fractiontoken.attach(faddress[0]);
            const fractiontokenIstance2 = await fractiontoken.attach(faddress[1]);
            expect(await fractiontokenIstance1.balanceOf(owner.address)).to.equal(100);
            expect(await fractiontokenIstance2.balanceOf(owner.address)).to.equal(150);
            expect(await fractionalize.getUserFractions(owner.address)).to.have.lengthOf(2);
            await fractiontokenIstance1.connect(owner).transfer(otherAccount1.address, 100);
            expect(await fractionalize.getUserFractions(owner.address)).to.deep.equal([faddress[1]]);
            expect(await fractionalize.getUserFractions(otherAccount1.address)).to.deep.equal([faddress[0]]);
            await fractiontokenIstance1.connect(otherAccount1).transfer(owner.address,100)
            expect(await fractionalize.getUserFractions(owner.address)).to.deep.equal([faddress[1],faddress[0]]);
            expect(await fractionalize.getUserFractions(otherAccount1.address)).to.deep.equal([]);
            await fractionalize.withdrawNft(faddress[1]);
            expect(await fractionalize.getUserFractions(owner.address)).to.have.deep.equal([faddress[0]]);
            await fractionalize.withdrawNft(faddress[0]);
            expect(await license.ownerOf(1)).to.equal(owner.address);
            expect(await license.ownerOf(2)).to.equal(owner.address);
        })
    })
});