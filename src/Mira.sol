// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import "@openzeppelin/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/utils/cryptography/ECDSA.sol";

/// @title Code Mira
/// @author ZKRLabs (zkrlabs.com)
/// @notice Gas-optimized ERC721A contract
contract Mira is ERC721 {
    /// @notice ECDSA library used for signature validation
    using ECDSA for bytes32;

    /// @notice Merkle tree library used for validation of user address in allowlist tree
    using MerkleProof for bytes32[];

    /// >>>>>>>>>>>>>>>>>>>>>>>>>  CUSTOM ERRORS   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    /// @notice Thrown if user address is not signed off or user is not an EOA
    error NotAuthorized();

    /// @notice Thrown if user is not on the allowlist
    error NotAllowed();

    /// @notice Thrown if user has reached maximum allowlist/public sale mints
    error AlreadyMinted();

    /// @notice Thrown if insufficient ether value was supplied
    error InsufficientValue();

    /// @notice Thrown if execution leads to failure
    error FailedAction();

    /// >>>>>>>>>>>>>>>>>>>>>>>>>  IMMUTABLES   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    address public immutable owner;

    uint256 public immutable allowlistMaxMint;
    uint256 public immutable publicMaxMint;
    uint256 public immutable maxSupply;
    uint256 public currentSupply;

    uint256 public constant AUCTION_START_PRICE = 150 wei;
    uint256 public constant AUCTION_END_PRICE = 15 wei;
    uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 340 minutes;
    uint256 public constant AUCTION_DROP_INTERVAL = 20 minutes;
    uint256 public constant AUCTION_DROP_PER_STEP =
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
            (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

    uint256 public constant price = 0.01 ether;

    /// >>>>>>>>>>>>>>>>>>>>>>>>>  CUSTOM STORAGE   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    string public baseTokenURI;

    bytes32 public merkleRoot;

    address public signerAddress = 0x165A20A378DEb66e5eF349cbeA72302838F2B0AF;

    uint32 public auctionSaleStartTime;

    mapping(address => uint256) public allowlistClaimed;
    mapping(address => uint256) public publicClaimed;

    /// >>>>>>>>>>>>>>>>>>>>>>>>>  CONSTRUCTOR   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        bytes32 _merkleRoot,
        uint256 _allowlistMaxMint,
        uint256 _publicMaxMint
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        merkleRoot = _merkleRoot;
        allowlistMaxMint = _allowlistMaxMint;
        publicMaxMint = _publicMaxMint;
        owner = msg.sender;
    }

    /// @dev Verify sender is a user and not a contract
    modifier callerIsUser() {
        if (tx.origin != msg.sender) revert NotAuthorized();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    function tokenURI(uint256)
        public
        pure
        virtual
        override
        returns (string memory)
    {}

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

    /// @dev Calculate sender hash, based on eth_sign JSON RPC
    function _senderHash() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abi.encodePacked(msg.sender))
                )
            );
    }

    /// @dev Validate computed sender hash matches input hash and recovered signer matches predefined signer address
    function _verify(bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool)
    {
        if (_senderHash() != hash) {
            return false;
        }
        return hash.recover(signature) == signerAddress;
    }

    /// @dev Safe mint reserved quantity for marketing and development
    function mintReserved(uint256 quantity) external onlyOwner {
        _safeMint(msg.sender, quantity);
    }

    /// @dev Mint for allowlist sale
    function mintAllowlist(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        callerIsUser
    {
        if (!(verifyAllowlist(proof, msg.sender))) revert NotAllowed();
        if (allowlistClaimed[msg.sender] + quantity > allowlistMaxMint)
            revert AlreadyMinted();
        if (msg.value < quantity * price) revert InsufficientValue();
        if (currentSupply + quantity > maxSupply) revert FailedAction();

        allowlistClaimed[msg.sender] += quantity;
        currentSupply += quantity;

        _safeMint(msg.sender, quantity);
    }

    /// @dev Mint for public sale, limited to `publicMaxMints`
    function mintPublicSale(
        uint256 quantity,
        bytes32 hash,
        bytes memory signature
    ) external payable callerIsUser {
        uint256 auctionPrice = getAuctionPrice();

        if (!(_verify(hash, signature))) revert NotAuthorized();
        if (publicClaimed[msg.sender] + quantity > publicMaxMint)
            revert AlreadyMinted();
        if (msg.value < quantity * auctionPrice) revert InsufficientValue();
        if (currentSupply + quantity > maxSupply) revert FailedAction();

        publicClaimed[msg.sender] += quantity;
        currentSupply += quantity;

        _safeMint(msg.sender, quantity);

        uint256 refund = msg.value - auctionPrice;
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
    function withdrawFunds() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert FailedAction();
    }

    function _baseURI() internal view virtual returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseTokenURI = uri;
    }
}
