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

    address public signerAddress = 0x165A20A378DEb66e5eF349cbeA72302838F2B0AF;

    string private _baseTokenURI;

    uint32 public auctionSaleStartTime;

    uint256 public constant AUCTION_START_PRICE = 150 wei;
    uint256 public constant AUCTION_END_PRICE = 15 wei;
    uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 340 minutes;
    uint256 public constant AUCTION_DROP_INTERVAL = 20 minutes;
    uint256 public constant AUCTION_DROP_PER_STEP =
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
            (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

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

    function _senderHash() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abi.encodePacked(msg.sender))
                )
            );
    }

    function verify(bytes32 _hash, bytes memory _signature)
        public
        view
        returns (bool)
    {
        if (_senderHash() != _hash) {
            return false;
        }
        return _hash.recover(_signature) == signerAddress;
    }

    /// @dev Mint reserved quantity for marketing and development.
    function mintReserved(uint256 _quantity) external onlyOwner {
        _safeMint(msg.sender, _quantity);
    }

    /// @dev Mint reserved quantity for marketing and development.
    function mintAllowlist(uint256 _quantity, bytes32[] calldata _merkleProof)
        external
        payable
        callerIsUser
    {
        if (!(verifyAllowlist(_merkleProof, msg.sender))) revert NotAllowed();
        if (allowlistClaimed[msg.sender] + _quantity > allowlistMaxMint)
            revert AlreadyMinted();
        if (msg.value < _quantity * price) revert InsufficientValue();
        if (totalSupply() + _quantity > collectionSize) revert InvalidAction();

        allowlistClaimed[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    /// @dev Mint for public sale, limited to `publicMaxMints`.
    function mintPublicSale(
        uint256 _quantity,
        bytes32 _hash,
        bytes memory _signature
    ) external payable callerIsUser {
        // SaleConfig memory config = saleConfig;
        // uint256 publicSaleKey = uint256(config.publicSaleKey);
        // uint256 publicPrice = uint256(config.publicPrice);
        // uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);
        uint256 price = getAuctionPrice();

        if (!(verify(_hash, _signature))) revert NotAuthorized();
        if (publicClaimed[msg.sender] + _quantity > publicMaxMint)
            revert AlreadyMinted();
        if (msg.value < _quantity * price) revert InsufficientValue();
        if (totalSupply() + _quantity > collectionSize) revert InvalidAction();

        publicClaimed[msg.sender] += _quantity;

        _safeMint(msg.sender, _quantity);
        uint256 refund = msg.value - price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function getAuctionPrice() public view returns (uint256) {
        if (block.timestamp < auctionSaleStartTime) {
            return AUCTION_START_PRICE;
        }
        if (
            block.timestamp - auctionSaleStartTime >= AUCTION_PRICE_CURVE_LENGTH
        ) {
            return AUCTION_END_PRICE;
        } else {
            uint256 steps = (block.timestamp - auctionSaleStartTime) /
                AUCTION_DROP_INTERVAL;
            return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
        }
    }

    function getTimeTillDrop() public view returns (uint256) {
        if (block.timestamp < auctionSaleStartTime) {
            return 0;
        }
        if (
            block.timestamp - auctionSaleStartTime >= AUCTION_PRICE_CURVE_LENGTH
        ) {
            return 0;
        } else {
            uint256 steps = (block.timestamp - auctionSaleStartTime) /
                AUCTION_DROP_INTERVAL;
            uint256 timeTillNextStep = ((steps + 1) * AUCTION_DROP_INTERVAL) -
                (block.timestamp - auctionSaleStartTime);
            return timeTillNextStep;
        }
    }

    function setAuctionStart(uint32 timestamp) external onlyOwner {
        auctionSaleStartTime = timestamp;
    }

    //   function setPublicSaleKey(uint32 key) external onlyOwner {
    //     saleConfig.publicSaleKey = key;
    //   }

    /// @dev Transfer contract funds to owner address.
    function withdrawFunds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert InvalidAction();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
}
