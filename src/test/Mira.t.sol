// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Mira} from "../Mira.sol";
import {Vm} from "forge-std/Vm.sol";

contract ContractTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    Mira internal mira;
    address payable[] internal users;

    string public name = "Mira";
    string public symbol = "MIRA";

    uint256 public allowlistMaxMint = 3;
    uint256 public publicMaxMint = 3;
    uint256 public collectionSize = 10000;
    uint256 public price = 1;
    bytes32 public merkleRoot = "";

    uint256 public constant AUCTION_START_PRICE = 1 ether;
    uint256 public constant AUCTION_END_PRICE = 0.15 ether;

    uint256 public receivedEther = 0;

    string private _baseTokenURI = "";

    bytes32[] public proof;

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
        utils = new Utilities();
        users = utils.createUsers(5);
    }

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

    function testExample() public {
        address payable alice = users[0];
        // labels alice's address in call traces as "Alice [<address>]"
        vm.label(alice, "Alice");
        console.log("alice's address", alice);
        address payable bob = users[1];
        vm.label(bob, "Bob");

        vm.prank(alice);
        (bool sent, ) = bob.call{value: 10 ether}("");
        assertTrue(sent);
        assertGt(bob.balance, alice.balance);
    }
}
