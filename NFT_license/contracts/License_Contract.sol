// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract License_Contract is ERC721URIStorage,IERC721Receiver, Ownable {

    //handle token storage for owner
    mapping (address => uint256[]) tokenIds;

    function balanceOf(address owner) public view virtual override returns (uint256) {
        return tokenIds[owner].length;
    }

//    function tokenOfOwnerByIndex(address owner, uint256 index) external view virtual returns (uint256) {
//        require(index < tokenIds[owner].length, "Index out of bounds");
//        return tokenIds[owner][index];
//    }

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
    // mapping from tokenId to parent tokenId
    mapping (uint256 => uint256) public parentToken;
    // mapping from parent tokenId to child tokenIds
    mapping (uint256 => uint256[]) public childTokens;
    //mapping token to its core attributes
    mapping (uint256 => Attribute[]) public tokenAttributes;
    //mapping parent token to its total share value
    mapping (uint256 => uint256) public totalShareValue;
    //mapping children token to its share value
    mapping (uint256 => uint256) public shareValue;
    //mapping token to its parts
    mapping (uint256 => uint256[]) public parts;
    //mapping parts to its parent token
    mapping (uint256 => uint256) public originalToken;
    //Token ids counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    //Events
    event LicenseCreated(address indexed owner, uint256 indexed tokenId, string tokenURI);

    constructor() ERC721("LicenseNFT", "LNFT") {
    }

    // mint a new token with tokenURI
    function mint(address to,string memory tokenURI) external onlyOwner{
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        emit LicenseCreated(msg.sender, newTokenId, tokenURI);
    }

    function mintWithAttributes(address to, string memory tokenURI, string[] memory attributes, string[] memory values) external onlyOwner{
        require(attributes.length == values.length, "Attributes and values must have the same length");
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        for(uint256 i = 0; i < attributes.length; i++){
            tokenAttributes[newTokenId].push(Attribute(attributes[i], values[i]));
        }
        emit LicenseCreated(msg.sender, newTokenId, tokenURI);
    }

    // split the token into multiple tokens
    function splitWithShares(uint256 tokenId, string[] memory tokenURIs, uint256[] memory shares) external {
        //check if there is more than one tokenURI
        require(tokenURIs.length > 1, "There must be more than one child token");
        // check if sender is the owner of the token
        require(ownerOf(tokenId) == msg.sender);
        //check if the sum of share is equal to tokenURIs
        require(shares.length == tokenURIs.length, "Shares and tokenURIs must have the same length");
        // transfer the original token to the contract itself
        safeTransferFrom(msg.sender, address(this), tokenId);
        uint256 totalShares = 0;
        for(uint256 i = 0; i < shares.length; i++){
            require(shares[i] > 0, "Shares must be greater than 0");
        }
        // create new tokens
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _mint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, tokenURIs[i]);
            // map the new token to the original token
            parentToken[newTokenId] = tokenId;
            // map the original token to the new token
            childTokens[tokenId].push(newTokenId);
            //up date each share the child has in this case all equal to 1
            shareValue[newTokenId] = shares[i];
            totalShares += shares[i];
            //make children inherit their parents attributes
            tokenAttributes[newTokenId] = tokenAttributes[tokenId];
        }
        // update the total share value of the parent token
        totalShareValue[tokenId] = totalShares;
    }

    function getNextId()  external view returns (uint256){
        uint256 nextId = _tokenIds.current();
        return nextId+1;
    }

    // merge the children tokens into the parent token
    function merge(uint256[] memory tokenIds) external {
        //check if all tokens are from the same parent
        uint256 parentTokenId = parentToken[tokenIds[0]];
        require(_exists(parentTokenId), "Token does not have parent");
        while(parentToken[parentTokenId] != 0){
            parentTokenId = parentToken[parentTokenId];
        }
        // check if all children are present
        uint256[] memory alldescendants = getAllDescendants(parentTokenId);
        require(compareArrays(alldescendants,tokenIds), "Descendants are not from the same ancestor or not all descendants are present");
        // check if sender is the owner of all tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender);
        }
        // transfer the parent token back to the sender
        _transfer(address(this), msg.sender, parentTokenId);
        // burn the children tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
        childTokens[parentTokenId] = new uint256[](0);
        totalShareValue[parentTokenId] = 0;
    }

    function getAttributes(uint256 tokenId) public view returns (string[] memory){
        require(_exists(tokenId), "Token does not exist");
        string[] memory result = new string[](tokenAttributes[tokenId].length);
        for(uint256 i = 0; i < tokenAttributes[tokenId].length; i++){
            result[i] = string(abi.encodePacked(tokenAttributes[tokenId][i].name,"$", tokenAttributes[tokenId][i].value));
        }
        return result;
    }


    function getParent(uint256 tokenId) public view returns (uint256){
        require(_exists(tokenId), "Token does not exist");
        return parentToken[tokenId];
    }

    function getChildren(uint256 tokenId) public view returns (uint256[] memory){
        require(_exists(tokenId), "Token does not exist");
        return childTokens[tokenId];
    }

    //handle shares values
    function getSharesOfChild(uint256 tokenId) public view returns (uint256){
        require(_exists(tokenId), "Token does not exist");
        return shareValue[tokenId];
    }

    function getCurrentTotalShares(uint256 tokenId) public view returns (uint256){
        require(_exists(tokenId), "Token does not exist");
        return totalShareValue[tokenId];
    }

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

    function getAllDescendants(uint256 ancestor) public view returns(uint256[] memory) {
        uint256[] memory descendants;
        uint256[] memory childrenIds = childTokens[ancestor];
        if(childrenIds.length == 0) {
            descendants = new uint256[](1);
            descendants[0] = ancestor;
            return descendants;
        }
        uint256 totalLength;
        for(uint256 i = 0; i < childrenIds.length; i++) {
            uint256[] memory grandchildren = getAllDescendants(childrenIds[i]);
            totalLength += grandchildren.length;
        }
        descendants = new uint256[](totalLength);
        uint256 index = 0;
        for(uint256 i = 0; i < childrenIds.length; i++) {
            uint256[] memory grandchildren = getAllDescendants(childrenIds[i]);
            for(uint256 j = 0; j < grandchildren.length; j++) {
                descendants[index] = grandchildren[j];
                index++;
            }
        }
        return descendants;
    }

    //partioning by attributes

    function separate(uint256 tokenId) external{
        require(parentToken[tokenId] == 0, "Token must be original");
        //check if token exists
        require(_exists(tokenId), "Token does not exist");
        //check if sender is the owner of the token
        require(ownerOf(tokenId) == msg.sender);
        //check if token has attributes
        require(tokenAttributes[tokenId].length > 1, "Token has no attributes/only one attribute");
        //transfer the original token to the contract itself
        safeTransferFrom(msg.sender, address(this), tokenId);
        //create new tokens
        for (uint256 i = 0; i < tokenAttributes[tokenId].length; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _mint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, tokenURI(tokenId));
            // map the new token to the original token
            originalToken[newTokenId] = tokenId;
            // map the original token to the new token
            parts[tokenId].push(newTokenId);
            //make children inherit their parents attributes
            tokenAttributes[newTokenId].push(tokenAttributes[tokenId][i]);
        }
    }

    function combine(uint256[] memory tokenId) external{
        //check if all tokens are from the same parent
        uint256 parentTokenId = originalToken[tokenId[0]];
        require(_exists(parentTokenId), "Token does not exist");
        // check if all children are present
        uint256[] memory allparts = parts[parentTokenId];
        require(compareArrays(allparts,tokenId), "Parts are not from the same ancestor or not all parts are present");
        // check if sender is the owner of all tokens
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == msg.sender,"Invalid combine");
        }
        // transfer the parent token back to the sender
        _transfer(address(this), msg.sender, parentTokenId);
        // burn the children tokens
        for (uint256 i = 0; i < tokenId.length; i++) {
            _burn(tokenId[i]);
        }
        parts[parentTokenId] = new uint256[](0);
    }

    function getOriginal(uint256 tokenId) external view returns (uint256){
        require(_exists(tokenId), "Token does not exist");
        return originalToken[tokenId];
    }

    function getParts(uint256 tokenId) external view returns (uint256[] memory){
        require(_exists(tokenId), "Token does not exist");
        return parts[tokenId];
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
