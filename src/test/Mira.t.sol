// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {Mira} from "../Mira.sol";
import {console} from "./utils/Console.sol";

contract ContractTest is DSTestPlus {
    Mira mira;

    string public name = "Mira";
    string public symbol = "MIRA";
    uint256 public allowlistMaxMint = 3;
    uint256 public publicMaxMint = 3;
    uint256 public collectionSize = 10000;
    uint256 public price = 1;
    bytes32 public merkleRoot =
        0xc7b446a7bb5ff3ddb5be4b1e5540590bd76d810ec4b40d89afd926707410e218;
    uint256 public constant AUCTION_START_PRICE = 1 ether;
    uint256 public constant AUCTION_END_PRICE = 0.15 ether;
    uint256 public receivedEther = 0;
    string private _baseTokenURI = "";

    function setUp() public {
        mira = new Mira(
            name,
            symbol,
            collectionSize,
            merkleRoot,
            allowlistMaxMint,
            publicMaxMint,
            price
        );
        mira.setBaseURI(_baseTokenURI);
    }

    // @notice Test metadata and immutable config
    function testConfig() public {
        assert(
            keccak256(abi.encodePacked(mira.name())) ==
                keccak256(abi.encodePacked(name))
        );
        assert(
            keccak256(abi.encodePacked(mira.symbol())) ==
                keccak256(abi.encodePacked(symbol))
        );
        assert(mira.merkleRoot() == merkleRoot);
        assert(mira.collectionSize() == collectionSize);
        assert(mira.allowlistMaxMint() == allowlistMaxMint);
        assert(mira.publicMaxMint() == publicMaxMint);
        assert(mira.price() == price);
    }

    // @notice Test allowlist minting with merkle tree validation
    function testMint() public {
        // Parse merkle proof
        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;
        proof[
            1
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;

        // Parse bad merkle proof
        bytes32[] memory badProof = new bytes32[](2);
        badProof[
            0
        ] = 0x000a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;
        badProof[
            1
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;

        // Check if address is on allowlist
        mira.verifyAllowlist(proof, address(1337));

        // Expect revert minted from smart contract not user wallet
        hoax(address(1337));
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        mira.mintAllowlist(proof, 3);

        // Set tx.origin and msg.sender for user address testing
        startHoax(address(1337), address(1337));

        // Expect revert no ether sent
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
        );
        mira.mintAllowlist(proof, uint256(3));

        // Expect revert not enough ether provided
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
        );
        mira.mintAllowlist{value: 1}(proof, uint256(3));

        // Expect revert no ether sent
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
        );
        mira.mintAllowlist(proof, uint256(3));

        // Expect revert bad proof submitted
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAllowed()"))));
        mira.mintAllowlist(badProof, uint256(3));

        // Successfully mint tokens
        mira.mintAllowlist{value: 3}(proof, uint256(3));

        // Expect revert already minted max mints
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("AlreadyMinted()"))));
        mira.mintAllowlist(proof, uint256(3));
        vm.stopPrank();

        // Expect revert invalid proof + not on allowlist
        hoax(address(0xBEEF), address(0xBEEF));
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAllowed()"))));
        mira.mintAllowlist(proof, uint256(3));

        // Validate mints
        assert(mira.totalSupply() == uint256(3));
        assert(mira.allowlistClaimed(address(1337)) == uint256(3));
    }

    function testRestrictedMint() public {}

    function testWithdraw() public {
        // Non-owner shouldn't be able to withdraw
        hoax(address(0xBEEF), address(0xBEEF));
        vm.expectRevert("Ownable: caller is not the owner");
        mira.withdrawFunds();

        // Parse merkle proof
        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;
        proof[
            1
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;

        // Foward successful mint funds to contract balance
        hoax(address(1337), address(1337));
        mira.mintAllowlist{value: 2}(proof, 2);

        // Successful withdraw as owner
        uint256 beforeBalance = address(this).balance;
        mira.withdrawFunds();
        uint256 afterBalance = address(this).balance;
        assert(afterBalance - beforeBalance == uint256(2));
    }

    fallback() external payable {}
}
