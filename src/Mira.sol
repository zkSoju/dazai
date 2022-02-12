// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/utils/cryptography/ECDSA.sol";

/// @author Enigma Labs <gm@enigmalabs.gg>
contract Mira is Ownable, ReentrancyGuard, ERC721A {
  using ECDSA for bytes32;
  using MerkleProof for bytes32[];

  error NotAuthorized();
  error NotAllowed();
  error AlreadyMinted();
  error InsufficientValue();
  error ExceededMaxMints();
  error UnsafeRecipient();
  error InvalidAction();

  //   struct SaleConfig {
  //     uint32 auctionSaleStartTime;
  //     uint32 publicSaleStartTime;
  //     uint64 allowlistPrice;
  //     uint64 publicPrice;
  //     uint32 publicSaleKey;
  //   }

  //   SaleConfig public saleConfig;

  uint256 public allowlistMaxMint;
  uint256 public publicMaxMint;
  uint256 public collectionSize;
  uint256 public price;
  bytes32 public merkleRoot;

  address public signerAddress;

  string private _baseTokenURI;

  //   uint256 public constant AUCTION_START_PRICE = 1 ether;
  //   uint256 public constant AUCTION_END_PRICE = 0.15 ether;
  //   uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 340 minutes;
  //   uint256 public constant AUCTION_DROP_INTERVAL = 20 minutes;
  //   uint256 public constant AUCTION_DROP_PER_STEP =
  //     (AUCTION_START_PRICE - AUCTION_END_PRICE) /
  //       (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

  mapping(address => uint256) public allowlistClaimed;
  mapping(address => uint256) public publicClaimed;

  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _collectionSize,
    bytes32 _merkleRoot,
    uint256 _allowlistMaxMint,
    uint256 _publicMaxMint,
    uint256 _price
  ) ERC721A(_name, _symbol) {
    collectionSize = _collectionSize;
    merkleRoot = _merkleRoot;
    allowlistMaxMint = _allowlistMaxMint;
    publicMaxMint = _publicMaxMint;
    price = _price;
  }

  /// @dev Verify sender is a user and not a contract
  modifier callerIsUser() {
    if (tx.origin != msg.sender) revert NotAuthorized();
    _;
  }

  /// @dev Verify account address exists in Merkle Tree
  function verifyAllowlist(bytes32[] calldata proof, address account)
    public
    view
    returns (bool)
  {
    bytes32 leaf = keccak256(abi.encodePacked(account));
    return proof.verify(merkleRoot, leaf);
  }

  /// @dev Set a new merkle root for seeding new data.
  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    merkleRoot = _merkleRoot;
  }

  /// @dev Mint reserved quantity for marketing and development.
  function mintReserved(uint256 quantity) external onlyOwner {
    _safeMint(msg.sender, quantity);
  }

  /// @dev Mint reserved quantity for marketing and development.
  function mintAllowlist(bytes32[] calldata _merkleProof, uint256 quantity)
    external
    payable
    callerIsUser
  {
    if (!(verifyAllowlist(_merkleProof, msg.sender))) revert NotAllowed();
    if (allowlistClaimed[msg.sender] + quantity > allowlistMaxMint)
      revert AlreadyMinted();
    if (msg.value < quantity * price) revert InsufficientValue();
    if (totalSupply() + quantity > collectionSize) revert InvalidAction();

    allowlistClaimed[msg.sender] += quantity;
    _safeMint(msg.sender, quantity);
  }

  //   /// @dev Mint for public sale, limited to `publicMaxMints`.
  //   function mintPublicSale(uint256 quantity, bytes calldata hash)
  //     external
  //     payable
  //     callerIsUser
  //   {
  //     // SaleConfig memory config = saleConfig;
  //     // uint256 publicSaleKey = uint256(config.publicSaleKey);
  //     // uint256 publicPrice = uint256(config.publicPrice);
  //     // uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);
  //     if (!(_verify(_hash(msg.sender), hash))) revert NotAuthorized();
  //     if (publicClaimed[msg.sender] + quantity > publicMaxMint)
  //       revert AlreadyMinted();
  //     if (msg.value < quantity * price) revert InsufficientValue();
  //     if (totalSupply() + quantity > collectionSize) revert InvalidAction();

  //     publicClaimed[msg.sender] += quantity;

  //     _safeMint(msg.sender, quantity);
  //   }

  //   function getAuctionPrice(uint256 saleStartTime)
  //     public
  //     view
  //     returns (uint256)
  //   {
  //     if (block.timestamp < saleStartTime) {
  //       return AUCTION_START_PRICE;
  //     }
  //     if (block.timestamp - saleStartTime >= AUCTION_PRICE_CURVE_LENGTH) {
  //       return AUCTION_END_PRICE;
  //     } else {
  //       uint256 steps = (block.timestamp - saleStartTime) / AUCTION_DROP_INTERVAL;
  //       return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
  //     }
  //   }

  //   function setAuctionStart(uint32 timestamp) external onlyOwner {
  //     saleConfig.auctionSaleStartTime = timestamp;
  //   }

  //   function setPublicSaleKey(uint32 key) external onlyOwner {
  //     saleConfig.publicSaleKey = key;
  //   }

  /// @dev Transfer contract funds to owner address.
  function withdrawFunds() external onlyOwner nonReentrant {
    (bool success, ) = msg.sender.call{ value: address(this).balance }("");
    if (!success) revert InvalidAction();
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }
}
