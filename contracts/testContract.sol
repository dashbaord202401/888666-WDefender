// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @dev Custom error for insufficient payment with message and required amount.
error InsufficientPayment(string message, uint256 required);

/// @dev Custom error for exceeding mint limit with message and limit.
error MintLimitReached(string message, uint256 limitValue);

/// @title A contract for minting NFTs with various attributes and pricing.
/// @dev Extends ERC721URIStorage and Pausable from OpenZeppelin.
contract testContract is ERC721URIStorage, Pausable {
    using SafeMath for uint256;

    /// @notice The owner of the contract.
    /// @dev Address of the contract owner.
    address public owner;

    /// @dev Emitted when an NFT is minted.
    event NFTMinted(address indexed receiver, uint256 indexed tokenId, uint256 indexed attributes);

    /// @dev Emitted when excess value is transferred back to the sender after minting.
    event ExcessValueTransferred(
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 indexed amount
    );

    /// @dev Sets the mint threshold for the contract.
    /// @notice The minimum number of tokens required for minting.
    uint constant MINT_THRESHOLD_2k = 10;

    /// @dev Sets the base price for tokenId between 1E3 and 2E3.
    /// @notice The base price for transactions in the contract, denominated in ether.
    uint constant BASE_PRICE_2e3 = 0.0069 ether;

    mapping(uint256 => uint256) public tokenAttributes;
    mapping(string => bool) private _mintedURIs;

    /// @notice Total number of NFTs minted.
    uint256 public totalMint;

    /// @notice Maximum supply of NFTs.
    uint256 public maxSupply = 1e6;

    address private mintEthReceiver;
    uint256 private limit;
    uint256 private price;
    uint256 internal basePrice1e3 = 0.0042 ether;
    uint256 internal zeroAttributeBasePrices = 0.069 ether;
    uint256 internal basePrices = 0.0099 ether;

    /// @notice Sets the initial parameters for the contract.
    /// @param _mintEthReceiver The address to receive minting fees.
    constructor(address _mintEthReceiver) ERC721("Gemini", "GMN") {
        mintEthReceiver = _mintEthReceiver;
        owner = msg.sender;
    }

    /// @dev Modifier to restrict function access to the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner of the contract!");
        _;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Pauses the contract, disabling minting functions.
    /// @dev Only callable by the owner.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, enabling minting functions.
    /// @dev Only callable by the owner.
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Safely mints a new NFT.
    /// @dev Mints a new token to the specified address with tokenId, attributes and URI.
    /// @param to The address to mint the NFT to.
    /// @param tokenId The token ID for the new NFT.
    /// @param uri The URI for the NFT metadata.
    /// @param attributes The number of attributes for the NFT.
    function safeMint(
        address to,
        uint256 tokenId,
        string memory uri,
        uint256 attributes
    ) public payable whenNotPaused {
        require(tokenId < maxSupply, "TokenId not valid");
        require(totalMint < maxSupply, "Max supply reached");
        require(!_mintedURIs[uri], "Token URI is already minted");
        require(attributes <= 10, "Invalid attribute");

        // Pricing logic
        (tokenId < MINT_THRESHOLD_2k)
            ? ((tokenId < MINT_THRESHOLD_2k / 2) ? price = basePrice1e3 : price = BASE_PRICE_2e3)
            : price = calculatePrices(attributes);
        (tokenId < MINT_THRESHOLD_2k) ? limit = 1 : limit = 7;

        // Mint limit logic
        (tokenId < MINT_THRESHOLD_2k) ? limit = 1 : limit = 7;

        // Mint limit enforcement
        if (balanceOf(to) == limit) {
            revert MintLimitReached({message: "Mint Limit Reached", limitValue: limit});
        }

        // Payment verification
        if (msg.value < price) {
            revert InsufficientPayment({message: "Insufficient payment for NFT", required: price});
        }

        // Minting process
        totalMint++;
        _safeMint(to, tokenId);
        _mintedURIs[uri] = true;
        _setTokenURI(tokenId, uri);
        tokenAttributes[tokenId] = attributes;
        emit NFTMinted(to, tokenId, attributes);
        payable(mintEthReceiver).transfer(price);

        // Refund excess payment
        uint256 extraEthReceived = msg.value - price;
        if (extraEthReceived > 0) {
            payable(msg.sender).transfer(extraEthReceived);
            emit ExcessValueTransferred(msg.sender, tokenId, extraEthReceived);
        }
    }

    /// @notice Calculates the price for minting an NFT based on attributes.
    /// @dev Internal function for price calculation.
    /// @param attributesCount The number of attributes of the NFT.
    /// @return The calculated price for the given number of attributes.
    function calculatePrices(uint256 attributesCount) internal view returns (uint256) {
        if (attributesCount == 0) {
            return zeroAttributeBasePrices;
        } else {
            return basePrices + ((attributesCount - 1) * basePrice1e3);
        }
    }

    // Setter and Getter functions

    /// @notice Updates the base price for first 1000 tokenIds.
    /// @dev Callable only by the contract owner.
    /// @param basePrice1k The new base price for the first 1000 tokenIds in wei.
    function updateBasePrice1e3(uint256 basePrice1k) external onlyOwner {
        basePrice1e3 = basePrice1k;
    }

    /// @notice Retrieves the current base price for first 1000 tokenIds.
    /// @return The base price for the first 1000 tokenIds in wei.
    function getBasePrice1e3() public view returns (uint256) {
        return basePrice1e3;
    }

    /// @notice Retrieves the current base price for tokenIds between 1000 and 2000.
    /// @return The base price for the tokenIds between 1000 and 2000 in wei.
    function getBasePrice2e3() public pure returns (uint256) {
        return BASE_PRICE_2e3;
    }

    /// @notice Updates the base price for NFTs with attributes.
    /// @dev Callable only by the contract owner.
    /// @param basePriceAttribute The new base price for NFTs with attributes in wei.
    function updateBasePriceAttributes(uint256 basePriceAttribute) external onlyOwner {
        basePrices = basePriceAttribute;
    }

    /// @notice Retrieves the current base price for NFTs with attributes.
    /// @return The base price for NFTs with attributes in wei.
    function getBasePriceAttributes() public view returns (uint256) {
        return basePrices;
    }

    /// @notice Updates the base price for NFTs with zero attributes.
    /// @dev Callable only by the contract owner.
    /// @param basePriceZeroAttribute The new base price for NFTs with zero attributes in wei.
    function updateBasePriceZeroAttributes(uint256 basePriceZeroAttribute) external onlyOwner {
        zeroAttributeBasePrices = basePriceZeroAttribute;
    }

    /// @notice Retrieves the current base price for NFTs with zero attributes.
    /// @return The base price for NFTs with zero attributes in wei.
    function getBasePriceZeroAttributes() public view returns (uint256) {
        return zeroAttributeBasePrices;
    }

    /// @notice Updates the maximum supply of NFTs that can be minted.
    /// @dev Callable only by the contract owner.
    /// @param newMaxSupply The new maximum supply of NFTs.
    function updateMaxSupply(uint256 newMaxSupply) external onlyOwner {
        maxSupply = newMaxSupply;
    }

    /// @notice Updates the address to receive mint fees.
    /// @dev Callable only by the contract owner.
    /// @param mintAmountReceiver The address to receive minting fees.
    function updateMintAmountReceiver(address mintAmountReceiver) external onlyOwner {
        require(mintAmountReceiver != address(0), "Invalid address");
        mintEthReceiver = mintAmountReceiver;
    }

    /// @notice Retrieves the current address set to receive mint fees.
    /// @return The address currently set to receive mint fees.
    function getMintAmountReceiver() public view returns (address) {
        return mintEthReceiver;
    }

    /// @notice Updates the owner of the contract.
    /// @dev Callable only by the current owner.
    /// @param newOwner The address of the new owner.
    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // Additional functions for handling ether sent to the contract

    /// @notice Fallback function to handle ether sent to contract.
    receive() external payable {}

    /// @notice Fallback function to handle calls to undefined functions or ether sent to contract.
    fallback() external payable {}
}
