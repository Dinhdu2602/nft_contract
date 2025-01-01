const {ethers} = require("hardhat")

const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const {solidity} = require('ethereum-waffle')
const chai = require('chai')
chai.use(solidity)
const { expect } = require("chai")

describe("license", function () {
    async function deploylicense() {

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount1, otherAccount2] = await ethers.getSigners();
        // owner.estimateGas(3500000);

        const License = await ethers.getContractFactory("License_Contract");
        const license = await License.deploy();

        return {license, owner, otherAccount1, otherAccount2};
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
        }
    );
    describe("mint", function () {
            it("Should mint a license", async function () {
                const {license,owner,otherAccount1} = await loadFixture(deploylicense);
                await license.connect(owner).mint(owner.address,"example");
                expect(await license.balanceOf(owner.address)).to.equal(1);
            });
            it("Should not mint a license to other account", async function () {
                const {license,owner,otherAccount1} = await loadFixture(deploylicense);
                await expect(license.connect(otherAccount1).mint(owner.address,"example")).to.be.revertedWith("Ownable: caller is not the owner");
            })
            it("should mint a license and transfer it to other account", async function () {
                const {license,owner,otherAccount1} = await loadFixture(deploylicense);
                await license.connect(owner).mint(owner.address,"example");
                await license.connect(owner).transferFrom(owner.address,otherAccount1.address,1);
                expect(await license.balanceOf(otherAccount1.address)).to.equal(1);
                expect(await license.balanceOf(owner.address)).to.equal(0);
            })
            it("should mint three tokens", async function () {
                const {license,owner} = await loadFixture(deploylicense);
                await license.connect(owner).mint(owner.address,"example");
                await license.connect(owner).mint(owner.address,"example1");
                await license.connect(owner).mint(owner.address,"example2");
                expect(await license.tokenURI(1)).to.equal("example");
                expect(await license.tokenURI(2)).to.equal("example1");
                expect(await license.tokenURI(3)).to.equal("example2");
                expect(await license.balanceOf(owner.address)).to.equal(3);
            })
            it("should mint a license with attributes", async function () {
                const {license,owner} = await loadFixture(deploylicense);
                await license.connect(owner).mintWithAttributes(owner.address,"example",['a','b'],['1','2']);
                expect(await license.getAttributes(1)).to.deep.equal(["a$1","b$2"]);
            })
        });
    describe("merge_split", function () {
        it("should split a license", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            expect(await license.ownerOf(1)).to.equal(license.address);
            expect(await license.ownerOf(2)).to.equal(owner.address);
            expect(await license.ownerOf(3)).to.equal(owner.address);
            expect(await license.balanceOf(owner.address)).to.equal(2);
            expect(await license.tokenURI(2)).to.equal("example1");
            expect(await license.tokenURI(3)).to.equal("example2");
        })
        it("should merge two licenses", async function () {
            const {license,owner} =  await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            expect(await license.ownerOf(1)).to.equal(license.address);
            await license.connect(owner).merge([2,3]);
            expect(await license.balanceOf(owner.address)).to.equal(1);
            expect(await license.tokenURI(1)).to.equal("example");
        })
        it("Should not merge two licenses if not correct id", async function () {
            const {license,owner,otherAccount1} = await deploylicense();
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            expect(await license.ownerOf(1)).to.equal(license.address);
            await expect(license.connect(otherAccount1).merge([2,5])).to.be.revertedWith("Descendants are not from the same ancestor or not all descendants are present");
        })
        it("Should not merge two licenses if not correct parent", async function () {
            const {license,owner} = await deploylicense();
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            await license.connect(owner).splitWithShares(2,["example1","example2"],[1,1]);
            await expect(license.connect(owner).merge([3,5])).to.be.revertedWith("Descendants are not from the same ancestor or not all descendants are present");
        });
        it("Should compare children correctly", async function () {
            const {license,owner} = await deploylicense();
            expect(await license.compareArrays([5,2,7],[7,2,5])).to.equal(true);
        })
        it("Should return children correctly", async function () {
            const {license,owner} = await deploylicense();
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            const rel = await license.getChildren(1);
            const compare = [2,3];
            for(let i = 0; i < rel.length; i++){
                expect(rel[i]).to.equal(compare[i]);
            }
            await license.connect(owner).merge([2,3]);
            expect(await license.getChildren(1)).to.deep.equal([]);
            await license.connect(owner).splitWithShares(1,["example1","example2","example3"],[1,1,1]);
            await license.connect(owner).merge([4,5,6])
            expect(await license.ownerOf(1)).to.equal(owner.address);
        })
        it("Should merge decendants correctly", async function () {
            const {license,owner} = await deploylicense();
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            await license.connect(owner).splitWithShares(2,["example1","example2","example"],[1,1,1]);
            const alldecendants = await license.getAllDescendants(1);
            expect(await license.compareArrays(alldecendants,[5,3,4,6])).to.equal(true);
            expect(await license.compareArrays(alldecendants,[3,5,4,6])).to.equal(true);
            expect(await license.compareArrays(alldecendants,[6,5,4,3])).to.equal(true);
            await license.connect(owner).merge([5,3,4,6]);
            expect(await license.ownerOf(1)).to.equal(owner.address);
        })
        it("Should return blank children correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            const rel = await license.getChildren(1);
            expect(rel).to.deep.equal([]);
        })
        it("Should returns final descendants correctly", async function () {
            const {license,owner} = await deploylicense();
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            await license.connect(owner).splitWithShares(2,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(4,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(7,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(9,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(10,["example3","example4"],[1,1]);
            const rel = await license.getAllDescendants(1);
            expect(await license.compareArrays(rel,[3,5,6,8,12,13,11])).to.equal(true);
        })
        it("Should merge all descendants correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            await license.connect(owner).splitWithShares(2,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(4,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(7,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(9,["example3","example4"],[1,1]);
            await license.connect(owner).splitWithShares(10,["example3","example4"],[1,1]);
            await license.connect(owner).merge([3,5,6,8,12,13,11]);
            expect(await license.balanceOf(owner.address)).to.equal(1);
            expect(await license.tokenURI(1)).to.equal("example");
        })
        it("Should merge to the correct parent", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            await license.connect(owner).splitWithShares(2,["example3","example4"],[1,1]);
            await license.connect(owner).merge([4,5]);
            expect(await license.ownerOf(2)).to.equal(owner.address);
            expect(await license.ownerOf(3)).to.equal(owner.address);
        });
        it("Should mint with attributes and then separate correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mintWithAttributes(owner.address,"example",["name1","name2"],["1","2"]);
            expect(await license.getAttributes(1)).to.deep.equal(["name1$1","name2$2"]);
            await  license.connect(owner).separate(1);
            expect(await license.getAttributes(2)).to.deep.equal(["name1$1"]);
            expect(await license.getAttributes(3)).to.deep.equal(["name2$2"]);
            expect(await license.ownerOf(1)).to.equal(license.address);
            expect(await license.ownerOf(2)).to.equal(owner.address);
            expect(await license.ownerOf(3)).to.equal(owner.address);
            expect(await license.tokenURI(2)).to.equal("example");
        })
        it("Should mint with attributes and then combine correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mintWithAttributes(owner.address,"example",["name1","name2"],["1","2"]);
            expect(await license.getAttributes(1)).to.deep.equal(["name1$1","name2$2"]);
            await  license.connect(owner).separate(1);
            expect(await license.balanceOf(owner.address)).to.equal(2);
            await license.connect(owner).combine([2,3]);
            expect(await license.balanceOf(owner.address)).to.equal(1);
            expect(await license.getAttributes(1)).to.deep.equal(["name1$1","name2$2"]);
            expect(await license.ownerOf(1)).to.equal(owner.address);
            expect(await license.getParts(1)).to.deep.equal([]);
            await expect(license.getParts(2)).to.be.revertedWith("Token does not exist");
            await license.connect(owner).separate(1);
            const compare = [4,5]
            const parts = await license.getParts(1);
            for(let i = 0; i < 2; i++){
                expect(parts[i]).to.equal(compare[i]);
            }
        });

        it("Should mint correctly and then split but not merge due to not all parts are present", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2","example3"],[1,1,1]);
            await expect(license.connect(owner).merge([2,3])).to.be.revertedWith("Descendants are not from the same ancestor or not all descendants are present");
        });
        it("should not merge when children does not exist", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            await expect(license.connect(owner).merge([2,4])).to.be.revertedWith("Descendants are not from the same ancestor or not all descendants are present");
        });
        it("Should not split when there is less than 2 children", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await expect(license.connect(owner).splitWithShares(1,["example1"],[1])).to.be.revertedWith("There must be more than one child token");
        });
        it("Should split with shares correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,2]);
            expect(await license.getSharesOfChild(2)).to.equal(1);
            expect(await license.getSharesOfChild(3)).to.equal(2);
            expect(await license.getCurrentTotalShares(1)).to.equal(3);
        });
        it("Should equally split with shares correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,1]);
            expect(await license.getSharesOfChild(2)).to.equal(1);
            expect(await license.getSharesOfChild(3)).to.equal(1);
            expect(await license.ownerOf(2)).to.equal(owner.address);
            expect(await license.getCurrentTotalShares(1)).to.equal(2);
        });
        it("Should not combine when not all part are exist", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mintWithAttributes(owner.address,"example",["name1","name2","name3"],["1","2","3"]);
            await license.connect(owner).separate(1);
            await license.connect(owner).mint(owner.address,"example");
            await expect(license.connect(owner).combine([2,4,5])).to.be.revertedWith("Parts are not from the same ancestor or not all parts are present");
        });
        it("Should not separate when token is not original", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,2]);
            await expect(license.connect(owner).separate(2)).to.be.revertedWith("Token must be original");
        })
        it("Should merge correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,2]);
            await license.connect(owner).splitWithShares(2,["example3","example4"],[1,2]);
            await license.connect(owner).splitWithShares(3,["example5","example6","ex"],[1,2,1]);
            let alldescendants = await license.getAllDescendants(1);
            expect(await license.compareArrays(alldescendants,[4,5,6,7,8])).to.equal(true);
            await license.connect(owner).merge([4,5,6,7,8]);
            expect(await license.ownerOf(1)).to.equal(owner.address);
        })
    });
    describe("Get info",()=>{
        it("Should return correct tokens of owner", async function () {
            const {license,owner, otherAccount1} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).mint(owner.address,"example1");
            await license.connect(owner).mint(owner.address,"example2");
            await license.connect(owner).transferFrom(owner.address,otherAccount1.address,2);
            expect(await license.balanceOf(owner.address)).to.equal(2);
            const ls = await license.tokenOfOwner(owner.address);
            expect(ls[0]).to.equal(1);
            expect(ls[1]).to.equal(3);
        });
        it("Should get the right share of child ", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,2]);
            expect(await license.getSharesOfChild(2)).to.equal(1);
            expect(await license.getSharesOfChild(3)).to.equal(2);
            expect(await license.getCurrentTotalShares(1)).to.equal(3);
            expect(await license.getCurrentTotalShares(2)).to.equal(0);
            await  license.merge([2,3])
            expect(await license.getCurrentTotalShares(1)).to.equal(0);
        })
        it("Should return the right parent", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mint(owner.address,"example");
            await license.connect(owner).splitWithShares(1,["example1","example2"],[1,2]);
            expect(await license.getParent(2)).to.equal(1);
        })
        it("Should return the right parts", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mintWithAttributes(owner.address,"example",["name1","name2","name3"],["1","2","3"]);
            await license.connect(owner).separate(1);
            // expect(await license.getParts(1)).to.deep.equal([2,3,4]);
            await license.connect(owner).combine([2,3,4]);
            expect(await license.getParts(1)).to.deep.equal([]);
        })

        it("Should compare array correctly", async function () {
            const {license,owner} = await loadFixture(deploylicense);
            await license.connect(owner).mintWithAttributes(owner.address,"example",["name1","name2","name3"],["1","2","3"]);
            await license.connect(owner).separate(1);
            expect(await license.compareArrays([2,3,4],[2,3,4])).to.equal(true);
            expect(await license.compareArrays([5,3,4,6],[3,4,5,6])).to.equal(true);
        })
    })
});