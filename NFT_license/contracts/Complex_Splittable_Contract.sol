pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Complex_Splittable_Contract is ERC721URIStorage,IERC721Receiver, Ownable {

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
    // mapping from tokenId to parent tokenId
    mapping (uint256 => uint256[]) public parentTokens;
    // mapping from parent tokenId to child tokenIds
    mapping (uint256 => uint256[]) public childTokens;
    //mapping parent token to its total share value
    mapping (uint256 => uint256) public totalShareValue;
    //mapping children token to its share value
    mapping (uint256 => mapping(uint256 => uint256)) public shareOfChild;
    //Token ids counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    //Events
    event LicenseCreated(address indexed owner, uint256 indexed tokenId, string tokenURI);

    constructor() ERC721("SplittableNFT", "SPNFT") {
    }

    //supporting functions
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
                if(!contains(descendants, grandchildren[j])){
                    descendants[index] = grandchildren[j];
                    index++;
                }else{
                    continue;
                }
            }
        }
        uint reallength;
        for(uint i =0; i<totalLength; i++){
            if(descendants[i]!=0){
                reallength++;
            }
        }
        uint256[] memory realDescendants = new uint256[](reallength);
        uint256 realIndex = 0;
        for(uint i =0; i<totalLength; i++){
            if(descendants[i]==0){
                continue;
            }
            realDescendants[realIndex] = descendants[i];
            realIndex++;
        }
        return realDescendants;
    }

    function findAncestor(uint256 tokenId) internal view returns(uint256){
        require(_exists(tokenId), "Token does not exist");
        uint256[] memory ancestor = parentTokens[tokenId];
        while(parentTokens[ancestor[0]].length != 0){
            ancestor = parentTokens[ancestor[0]];
        }
        return ancestor[0];
    }

    // mint a new token with tokenURI
    function mint(address to,string memory tokenURI) external onlyOwner{
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        emit LicenseCreated(msg.sender, newTokenId, tokenURI);
    }


    function split(uint256 tokenId, uint256[] memory shares) external {
        //check if there is more than one tokenURI
        require(shares.length > 1, "There must be more than one child token");
        // check if sender is the owner of the token
        require(ownerOf(tokenId) == msg.sender);
        // transfer the original token to the contract itself
        safeTransferFrom(msg.sender, address(this), tokenId);
        uint256 totalShares = 0;
        for(uint256 i = 0; i < shares.length; i++){
            require(shares[i] > 0, "Shares must be greater than 0");
        }
        // create new tokens
        for (uint256 i = 0; i < shares.length; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _mint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, tokenURI(tokenId));
            // map the new token to the original token
            parentTokens[newTokenId] = [tokenId];
            // map the original token to the new token
            childTokens[tokenId].push(newTokenId);
            //update each share the child has in this case all equal to 1
            shareOfChild[newTokenId][tokenId] = shares[i];
            totalShares += shares[i];
        }
        // update the total share value of the parent token
        totalShareValue[tokenId] = totalShares;
    }

    function merge(uint256[] memory tokenIds) external {
        //check if all tokens are from the same parent
        uint256 parentTokenId = findAncestor(tokenIds[0]);
        // check if all children are present
        uint256[] memory alldescendants = getAllDescendants(parentTokenId);
        require(compareArrays(alldescendants,tokenIds), "Descendants are not from the same ancestor or not all descendants are present");
        // check if sender is the owner of all tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender);
        }
        // burn the children tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
        // transfer the parent token back to the sender
        _transfer(address(this), msg.sender, parentTokenId);
        childTokens[parentTokenId] = new uint256[](0);
        totalShareValue[parentTokenId] = 0;
    }

    function mergePercentage(uint256[] memory idlist) external{
        //check all token from the same parent
        uint256 ancestor = findAncestor(idlist[0]);
        for(uint256 i = 0; i < idlist.length; i++){
            require(findAncestor(idlist[i]) == ancestor, "Tokens are not from the same ancestor");
        }

        //check if sender is the owner of all tokens
        for(uint256 i = 0; i < idlist.length; i++){
            require(ownerOf(idlist[i]) == msg.sender, "Sender is not the owner of all tokens");
        }

        _tokenIds.increment();
        uint256 newtokenid = _tokenIds.current();
        _mint(msg.sender, newtokenid);
        // forming a new parent set and set share value
        for(uint256 i = 0; i < idlist.length; i++){
            childTokens[idlist[i]] = [newtokenid];
            parentTokens[newtokenid].push(idlist[i]);
            totalShareValue[idlist[i]] = 1;
            shareOfChild[newtokenid][idlist[i]] = totalShareValue[idlist[i]];
        }
    }

    function getShareValue(uint256 tokenId, uint256 parent) external view returns(uint256){
        require(_exists(tokenId), "Token does not exist");
        require(_exists(parent), "Ancestor does not exist");
        return shareOfChild[tokenId][parent];
    }

    function getParentList(uint256 tokenId) external view returns(uint256[] memory){
        require(_exists(tokenId), "Token does not exist");
        return parentTokens[tokenId];
    }
    function getTotalValue(uint256 tokenId) external view returns(uint256){
        require(_exists(tokenId), "Token does not exist");
        return totalShareValue[tokenId];
    }
    function getChildrenList(uint256 tokenId) external view returns(uint256[] memory){
        require(_exists(tokenId), "Token does not exist");
        return childTokens[tokenId];
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