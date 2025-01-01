pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Complex_Attributes_Contract is ERC721URIStorage,IERC721Receiver, Ownable {

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
    //Structs
    struct Attribute {
        string name;
        string value;
    }

    //logic handling functions
    //these handle merging functions
    function compareArrays(uint[] memory a, uint[] memory b) public pure returns(bool){
        if(a.length != b.length){
            return false;
        }
        for(uint i=0; i<a.length; i++){
            if(!contains(b, a[i])){
                return false;
            }
        }
        return true;
    }

    function contains(uint[] memory arr, uint elem) pure private returns (bool){
        for(uint i=0; i<arr.length; i++){
            if(arr[i] == elem){
                return true;
            }
        }
        return false;
    }

    function containsString(string[] memory arr, string memory elem) pure internal returns(bool){
        for(uint i=0; i<arr.length; i++){
            if(keccak256(abi.encodePacked(arr[i])) == keccak256(abi.encodePacked(elem))){
                return true;
            }
        }
        return false;
    }

    function containAttributes(Attribute[] memory arr, Attribute memory elem) pure internal returns(bool){
        for(uint i=0; i<arr.length; i++){
            if(keccak256(abi.encodePacked(arr[i].name)) == keccak256(abi.encodePacked(elem.name))){
                return true;
            }
        }
        return false;
    }

    //mapping tokens to their major attributes
    mapping (uint256 => Attribute) public tokenMajorAttribute;
    //mapping original to stored parts
    mapping (uint256 => uint256[]) public storedParts;
    //set token to accept types to be merged in
    mapping (uint256 => Attribute[]) acceptMajorAttributes;
    //Token ids counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("AttributesNFT", "ANFT") {}

    //main functions

    function mint(address to, string memory tokenURI, string memory majorName, string memory majorValue,
        string[] memory acceptNames, string[] memory acceptValues,
        string[] memory attributes, string[] memory values, string[] memory attrURI,
        string[][] memory acceptAttrNames, string[][] memory acceptAttrValue) external onlyOwner{
        require(attributes.length == values.length, "Attributes and values must have the same length");
        require(attributes.length == attrURI.length, "Attributes and URI must have the same length");
        require(acceptNames.length == acceptValues.length, "Accept names and values must have the same length");
        require(acceptAttrNames.length == attributes.length,"Each attributes must have a list of accept attributes");
        //handle new token
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        tokenMajorAttribute[newTokenId] = Attribute(majorName, majorValue);
        for(uint256 i = 0; i < acceptNames.length; i++){
            acceptMajorAttributes[newTokenId].push(Attribute(acceptNames[i], acceptValues[i]));
        }
        //handle attributes that go along with the token
        for(uint256 i = 0; i < attributes.length; i++){
            _tokenIds.increment();
            _mint(address(this), _tokenIds.current());
            _setTokenURI(_tokenIds.current(), attrURI[i]);
            tokenMajorAttribute[_tokenIds.current()] = Attribute(attributes[i], values[i]);
            for(uint256 j = 0; j < acceptAttrNames[i].length; j++){
                acceptMajorAttributes[_tokenIds.current()].push(Attribute(acceptAttrNames[j][i], acceptAttrValue[j][i]));
            }
            storedParts[newTokenId].push(_tokenIds.current());
        }
    }

    function addTrait(uint256 traitToken,uint256 addto) external{
        require(_exists(traitToken), "Token does not exist");
        require(_exists(addto), "Token does not exist");
        require(ownerOf(traitToken) == msg.sender, "Sender must be owner of trait token");
        require(ownerOf(addto) == msg.sender);
        require(containAttributes(acceptMajorAttributes[addto],tokenMajorAttribute[traitToken]),"Tokens type must be in accept types of addto token");
        storedParts[addto].push(traitToken);
        safeTransferFrom(msg.sender, address(this), traitToken);
    }

    function removeTraitAt(uint256 token, uint256 position) external{
        require(_exists(token), "Token does not exist");
        require(ownerOf(token) == msg.sender);
        require(position < storedParts[token].length, "Position not valid");
        _transfer(address(this), msg.sender, storedParts[token][position]);
        storedParts[token][position] = storedParts[token][storedParts[token].length - 1];
        storedParts[token].pop();
    }

    function getAttributes(uint256 tokenId) public view returns (string[] memory){
        require(_exists(tokenId), "Token does not exist");
        string[] memory result = new string[](storedParts[tokenId].length);
        uint[] memory parts = storedParts[tokenId];
        for(uint256 i = 0; i < parts.length; i++){
            result[i] = string(abi.encodePacked(tokenMajorAttribute[parts[i]].name,":", tokenMajorAttribute[parts[i]].value));
        }
        return result;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return
        bytes4(
            keccak256("onERC721Received(address,address,uint256,bytes)")
        );
    }
}