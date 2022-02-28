// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {MiraA} from "../MiraA.sol";
import {console} from "./utils/Console.sol";

contract ERC721ATest is DSTestPlus {
    MiraA mira;

    string public name = "Mira";
    string public symbol = "MIRA";
    uint256 public allowlistMaxMint = 10;
    uint256 public publicMaxMint = 10;
    uint256 public maxSupply = 10000;
    bytes32 public merkleRoot =
        0xc7b446a7bb5ff3ddb5be4b1e5540590bd76d810ec4b40d89afd926707410e218;
    uint256 public receivedEther = 0;
    string private _baseTokenURI = "";

    // Good proof
    bytes32[] public proof = new bytes32[](2);

    // Bad proof
    bytes32[] public badProof = new bytes32[](2);

    function setUp() public {
        mira = new MiraA(
            name,
            symbol,
            maxSupply,
            merkleRoot,
            allowlistMaxMint,
            publicMaxMint
        );
        mira.setBaseURI(_baseTokenURI);

        proof[
            0
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;
        proof[
            1
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;

        badProof[
            0
        ] = 0x000a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;
        badProof[
            1
        ] = 0x972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064;
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
        assert(mira.maxSupply() == maxSupply);
        assert(mira.allowlistMaxMint() == allowlistMaxMint);
        assert(mira.publicMaxMint() == publicMaxMint);
    }

    // @notice Test additional metadata sanity checks
    function testConfigSanity() public {
        mira.setAuctionStart(block.timestamp);

        // Assert for any time in the after end auction price is auction end price
        vm.warp(block.timestamp + mira.AUCTION_PRICE_CURVE_LENGTH());
        assertEq(mira.getAuctionPrice(), mira.AUCTION_END_PRICE());

        // Assert for any time in the before start auction price is auction start price
        vm.warp(mira.auctionSaleStartTime() - 1 seconds);
        assertEq(mira.getAuctionPrice(), mira.AUCTION_START_PRICE());
    }

    // @notice Test allowlist minting with merkle tree validation
    // function testMintSafety() public {
    //     // Parse merkle proof

    //     vm.label(address(1337), "1337");
    //     vm.label(address(0xBEEF), "BEEF");

    //     // Check if address is on allowlist
    //     mira.verifyAllowlist(proof, address(1337));
    //     mira.verifyAllowlist(proof, address(0xBEEF));

    //     // Expect revert minted from smart contract not user wallet
    //     hoax(address(1337));
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
    //     mira.mintAllowlist(uint256(3), proof);

    //     // Set tx.origin and msg.sender for user address testing
    //     startHoax(address(1337), address(1337));

    //     // Expect revert no ether sent
    //     vm.expectRevert(
    //         abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
    //     );
    //     mira.mintAllowlist(uint256(3), proof);

    //     // Expect revert not enough ether provided
    //     vm.expectRevert(
    //         abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
    //     );
    //     mira.mintAllowlist{value: 1}(uint256(3), proof);

    //     // Expect revert no ether sent
    //     vm.expectRevert(
    //         abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
    //     );
    //     mira.mintAllowlist(uint256(3), proof);

    //     // Expect revert bad proof submitted
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAllowed()"))));
    //     mira.mintAllowlist(uint256(3), badProof);

    //     // Successfully mint tokens
    //     mira.mintAllowlist{value: 3}(uint256(3), proof);
    //     assertEq(mira.balanceOf(address(1337)), 3);

    //     // Expect revert already minted max mints
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("AlreadyMinted()"))));
    //     mira.mintAllowlist(uint256(3), proof);
    //     vm.stopPrank();

    //     // Expect revert invalid proof + not on allowlist
    //     hoax(address(0xBEEF), address(0xBEEF));
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAllowed()"))));
    //     mira.mintAllowlist(uint256(3), proof);

    //     // Validate mints
    //     assert(mira.currentSupply() == uint256(3));
    //     assert(mira.allowlistClaimed(address(1337)) == uint256(3));
    // }

    // @notice Test owner withdraw
    function testWithdrawSafety() public {
        // Non-owner shouldn't be able to withdraw
        hoax(address(0xBEEF), address(0xBEEF));
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        mira.withdrawFunds();

        // Foward successful mint funds to contract balance
        hoax(address(1337), address(1337));
        mira.mintAllowlist{value: 2}(2, proof);

        // Successful withdraw as owner
        uint256 beforeBalance = address(this).balance;
        mira.withdrawFunds();
        uint256 afterBalance = address(this).balance;
        assert(afterBalance - beforeBalance == uint256(2));
    }

    // @notice Test offchain signature validation
    // function testSignature() public {
    //     startHoax(
    //         address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4),
    //         address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4)
    //     );

    //     // Ensure successful recovery of signer address
    //     bytes
    //         memory signature = hex"6c69643ab47e09b82e4a2bb692e412367ded1835d2ed7f569f7ba33a31a1559206237ec92e885fbe6bf54001b4ad73a08e44144ef0dde169e10734550ca5bde41c";

    //     bytes
    //         memory fakeSignature = hex"8c69643ab47e09b82e4a2bb692e412367ded1835d2ed7f569f7ba33a31a1559206237ec92e885fbe6bf54001b4ad73a08e44144ef0dde169e10734550ca5bde41c";

    //     bool isVerified = mira.verify(
    //         0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b24,
    //         signature
    //     );
    //     assertTrue(isVerified);

    //     // Assert false for incorrect RPC message hash of msg.sender
    //     bool isFakeHash = mira.verify(
    //         0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b88,
    //         signature
    //     );
    //     assertTrue(!isFakeHash);

    //     // Expect revert for incorrect signature/signer
    //     vm.expectRevert(abi.encodePacked("ECDSA: invalid signature"));
    //     bool isFakeSigner = mira.verify(
    //         0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b24,
    //         fakeSignature
    //     );
    //     vm.stopPrank();
    // }

    // @notice Test public sale signed mint
    function testSignedMintSafety() public {
        startHoax(
            address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4),
            address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4)
        );

        bytes
            memory signature = hex"6c69643ab47e09b82e4a2bb692e412367ded1835d2ed7f569f7ba33a31a1559206237ec92e885fbe6bf54001b4ad73a08e44144ef0dde169e10734550ca5bde41c";
        bytes
            memory fakeSignature = hex"8c69643ab47e09b82e4a2bb692e412367ded1835d2ed7f569f7ba33a31a1559206237ec92e885fbe6bf54001b4ad73a08e44144ef0dde169e10734550ca5bde41c";

        bytes32 incorrectSenderHash = keccak256(
            abi.encodePacked(
                address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4)
            )
        );

        bytes32 senderHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4)
                    )
                )
            )
        );

        // Expect revert no ether sent
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
        );
        mira.mintPublicSale{value: 0}(uint256(1), senderHash, signature);

        // Expect revert fake credentials
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        mira.mintPublicSale{value: 1}(
            uint256(1),
            incorrectSenderHash,
            signature
        );

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        mira.mintPublicSale{value: 1}(
            uint256(1),
            incorrectSenderHash,
            fakeSignature
        );

        vm.expectRevert(abi.encodePacked("ECDSA: invalid signature"));
        mira.mintPublicSale{value: 1}(uint256(1), senderHash, fakeSignature);

        // Ensure successful mint provided correct credentials
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
        );
        mira.mintPublicSale{value: 1}(uint256(1), senderHash, signature);
        vm.stopPrank();
    }

    function testIsolatedSingleMint() public {
        hoax(address(1337), address(1337));
        mira.mintAllowlist{value: 1}(1, proof);
    }

    function testIsolatedMultiMint() public {
        hoax(address(1337), address(1337));
        mira.mintAllowlist{value: 10}(10, proof);
    }

    fallback() external payable {}
}
