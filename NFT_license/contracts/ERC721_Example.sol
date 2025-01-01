pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ERC721_Example is ERC721URIStorage, Ownable{
    //handle token storage for owner
    mapping (address => uint256[]) tokenIds;

    function balanceOf(address owner) public view virtual override returns (uint256) {
        return tokenIds[owner].length;
    }

    function tokenOfOwner(address owner) external view virtual returns (uint256[] memory) {
        return tokenIds[owner];
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        super._mint(to, tokenId);
        tokenIds[to].push(tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        super._transfer(from, to, tokenId);
        uint256 index = _indexOf(tokenIds[from], tokenId);
        tokenIds[from][index] = tokenIds[from][tokenIds[from].length - 1];
        tokenIds[from].pop();
        tokenIds[to].push(tokenId);
    }

    function _burn (uint256 tokenId) internal virtual override {
        address owner = ownerOf(tokenId);
        uint256 index = _indexOf(tokenIds[owner], tokenId);
        tokenIds[owner][index] = tokenIds[owner][tokenIds[owner].length - 1];
        tokenIds[owner].pop();
        super._burn(tokenId);
    }

    function _indexOf(uint256[] storage array, uint256 element) private view returns (uint256) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return i;
            }
        }
        revert("Element not found in array");
    }

    constructor() ERC721("ERC721_Example", "ERC721E"){
        price = 0.1 ether;
    }

    uint256 price;
    event NFT_Created(address indexed owner, uint256 indexed tokenId, string tokenURI);
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    function mint(address to,string memory tokenURI) public payable{
        require(msg.value >= price, "Insufficient funds");
        payable(owner()).transfer(price);
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        emit NFT_Created(msg.sender, newTokenId, tokenURI);
    }

    function setPrice(uint256 _price) external onlyOwner{
        price = _price;
    }

    function getPrice() external view returns(uint256){
        return price;
    }
}