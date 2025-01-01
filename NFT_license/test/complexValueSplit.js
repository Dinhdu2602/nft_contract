const {ethers, waffle} = require("hardhat")
const {BigNumber} = require("ethers")
const provider = waffle.provider

const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const {solidity} = require('ethereum-waffle')
const chai = require('chai')
chai.use(solidity)
const { expect } = require("chai")

describe("complex value splitter", function () {
    async function deployContract() {

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount1, otherAccount2] = await ethers.getSigners();
        // owner.estimateGas(3500000);

        const License = await ethers.getContractFactory("Complex_Splittable_Contract");
        const license = await License.deploy();

        return {license, owner, otherAccount1, otherAccount2};
    }

    async function calculatePercent(license,id){
        const parent = await license.getParentList(id);
        if (parent && parent.length === 0) return 1;
        let sum = 0;
        for (let i = 0; i < parent.length; i++){
            let sharevalue = await license.getShareValue(id,parent[i]);
            let totalvalue = await license.getTotalValue(parent[i]);
            sum += sharevalue*(await calculatePercent(license,parent[i]))/(totalvalue);
        }
        return sum;
    }

    describe("deploying", function () {
        it("should deploy", async function () {
            const {license} = await loadFixture(deployContract);
            expect(await license.owner()).to.not.equal(0);
        });
    });
    describe("minting", function () {
        it("should mint a token", async function () {
            const {license, owner} = await loadFixture(deployContract);
            await license.mint(owner.address, "https://ipfs.io/");
            expect(await license.balanceOf(owner.address)).to.equal(1);
        });
    });

    describe("splitting", function () {
        it("should split a token", async function () {
            const {license, owner, otherAccount1, otherAccount2} = await loadFixture(deployContract);
            await license.mint(owner.address, "https://ipfs.io/");
            await license.connect(owner).split(1,[1,2]);
            expect(await license.ownerOf(1)).to.equal(license.address);
            expect(await license.ownerOf(2)).to.equal(owner.address);
            expect(await license.ownerOf(3)).to.equal(owner.address);
        })

        it("Should split a token and merge percentages", async function () {
            const {license, owner, otherAccount1, otherAccount2} = await loadFixture(deployContract);
            await license.mint(owner.address, "https://ipfs.io/");
            await license.connect(owner).split(1,[1,2]);
            await license.connect(owner).split(2,[1,2]);
            await license.connect(owner).split(3,[1,2]);

            await license.connect(owner).mergePercentage([4,6])

            const des = await license.getAllDescendants(1);
            console.log(des);
            expect(des).to.deep.equal([BigNumber.from(8),BigNumber.from(5),BigNumber.from(7)])
        })
        it("Should split and then calculate percentages", async function () {
            const {license, owner} = await loadFixture(deployContract);
            await license.mint(owner.address, "https://ipfs.io/");
            await license.connect(owner).split(1,[1,1]);
            await license.connect(owner).split(2,[1,1]);
            await license.connect(owner).mergePercentage([3,4]);
            const percent = await calculatePercent(license,6);
            expect(percent).to.equal(0.75);
            expect(await license.getAllDescendants(1)).to.deep.equal([BigNumber.from(6),BigNumber.from(5)])
            console.log('percent',percent.toString());
            await license.connect(owner).merge([5,6]);
            expect(await license.ownerOf(1)).to.equal(owner.address);
        })
        it("Should split and then calculate percentages", async function () {
            const {license, owner} = await loadFixture(deployContract);
            await license.mint(owner.address, "https://ipfs.io/");
            await license.connect(owner).split(1,[1,1]);
            await license.connect(owner).split(2,[1,1]);
            await license.connect(owner).split(3,[1,1]);
            await license.connect(owner).mergePercentage([4,5,6]);
            expect(await calculatePercent(license,8)).to.equal(0.75);
            console.log(await license.getAllDescendants(1));
            await license.connect(owner).merge([8,7]);
            expect(await license.ownerOf(1)).to.equal(owner.address);
        })
        it("Should split and then calculate percentages", async function () {
            const {license, owner} = await loadFixture(deployContract);
            await license.mint(owner.address, "https://ipfs.io/");
            await license.connect(owner).split(1,[1,1,1,1,1]);
            await license.connect(owner).split(2,[1,1]);
            await license.connect(owner).split(3,[1,1]);
            await license.connect(owner).mergePercentage([7,8,5]);
            expect(await calculatePercent(license,11)).to.equal(0.4);
        })
    })
})