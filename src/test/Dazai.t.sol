// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Dazai} from "../Dazai.sol";

import "@std/Test.sol";

contract DazaiTest is Test {
    Dazai dazai;

    string public name = "Dazai";
    string public symbol = "DZA";
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
        dazai = new dazaiA(
            name,
            symbol,
            maxSupply,
            merkleRoot,
            allowlistMaxMint,
            publicMaxMint
        );
        dazai.setBaseURI(_baseTokenURI);

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
            keccak256(abi.encodePacked(dazai.name())) ==
                keccak256(abi.encodePacked(name))
        );
        assert(
            keccak256(abi.encodePacked(dazai.symbol())) ==
                keccak256(abi.encodePacked(symbol))
        );
        assert(dazai.merkleRoot() == merkleRoot);
        assert(dazai.maxSupply() == maxSupply);
        assert(dazai.allowlistMaxMint() == allowlistMaxMint);
        assert(dazai.publicMaxMint() == publicMaxMint);
    }

    // @notice Test additional metadata sanity checks
    function testConfigSanity() public {
        dazai.setAuctionStart(block.timestamp);

        // Assert for any time in the after end auction price is auction end price
        vm.warp(block.timestamp + dazai.AUCTION_PRICE_CURVE_LENGTH());
        assertEq(dazai.getAuctionPrice(), dazai.AUCTION_END_PRICE());

        // Assert for any time in the before start auction price is auction start price
        vm.warp(dazai.auctionSaleStartTime() - 1 seconds);
        assertEq(dazai.getAuctionPrice(), dazai.AUCTION_START_PRICE());
    }

    // @notice Test allowlist minting with merkle tree validation
    // function testMintSafety() public {
    //     // Parse merkle proof

    //     vm.label(address(1337), "1337");
    //     vm.label(address(0xBEEF), "BEEF");

    //     // Check if address is on allowlist
    //     dazai.verifyAllowlist(proof, address(1337));
    //     dazai.verifyAllowlist(proof, address(0xBEEF));

    //     // Expect revert minted from smart contract not user wallet
    //     hoax(address(1337));
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
    //     dazai.mintAllowlist(uint256(3), proof);

    //     // Set tx.origin and msg.sender for user address testing
    //     startHoax(address(1337), address(1337));

    //     // Expect revert no ether sent
    //     vm.expectRevert(
    //         abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
    //     );
    //     dazai.mintAllowlist(uint256(3), proof);

    //     // Expect revert not enough ether provided
    //     vm.expectRevert(
    //         abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
    //     );
    //     dazai.mintAllowlist{value: 1}(uint256(3), proof);

    //     // Expect revert no ether sent
    //     vm.expectRevert(
    //         abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
    //     );
    //     dazai.mintAllowlist(uint256(3), proof);

    //     // Expect revert bad proof submitted
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAllowed()"))));
    //     dazai.mintAllowlist(uint256(3), badProof);

    //     // Successfully mint tokens
    //     dazai.mintAllowlist{value: 3}(uint256(3), proof);
    //     assertEq(dazai.balanceOf(address(1337)), 3);

    //     // Expect revert already minted max mints
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("AlreadyMinted()"))));
    //     dazai.mintAllowlist(uint256(3), proof);
    //     vm.stopPrank();

    //     // Expect revert invalid proof + not on allowlist
    //     hoax(address(0xBEEF), address(0xBEEF));
    //     vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAllowed()"))));
    //     dazai.mintAllowlist(uint256(3), proof);

    //     // Validate mints
    //     assert(dazai.currentSupply() == uint256(3));
    //     assert(dazai.allowlistClaimed(address(1337)) == uint256(3));
    // }

    // @notice Test owner withdraw
    function testWithdrawSafety() public {
        // Non-owner shouldn't be able to withdraw
        hoax(address(0xBEEF), address(0xBEEF));
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        dazai.withdrawFunds();

        // Foward successful mint funds to contract balance
        hoax(address(1337), address(1337));
        dazai.mintAllowlist{value: 2}(2, proof);

        // Successful withdraw as owner
        uint256 beforeBalance = address(this).balance;
        dazai.withdrawFunds();
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

    //     bool isVerified = dazai.verify(
    //         0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b24,
    //         signature
    //     );
    //     assertTrue(isVerified);

    //     // Assert false for incorrect RPC message hash of msg.sender
    //     bool isFakeHash = dazai.verify(
    //         0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b88,
    //         signature
    //     );
    //     assertTrue(!isFakeHash);

    //     // Expect revert for incorrect signature/signer
    //     vm.expectRevert(abi.encodePacked("ECDSA: invalid signature"));
    //     bool isFakeSigner = dazai.verify(
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
        dazai.mintPublicSale{value: 0}(uint256(1), senderHash, signature);

        // Expect revert fake credentials
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        dazai.mintPublicSale{value: 1}(
            uint256(1),
            incorrectSenderHash,
            signature
        );

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotAuthorized()"))));
        dazai.mintPublicSale{value: 1}(
            uint256(1),
            incorrectSenderHash,
            fakeSignature
        );

        vm.expectRevert(abi.encodePacked("ECDSA: invalid signature"));
        dazai.mintPublicSale{value: 1}(uint256(1), senderHash, fakeSignature);

        // Ensure successful mint provided correct credentials
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("InsufficientValue()")))
        );
        dazai.mintPublicSale{value: 1}(uint256(1), senderHash, signature);
        vm.stopPrank();
    }

    function testIsolatedSingleMint() public {
        hoax(address(1337), address(1337));
        dazai.mintAllowlist{value: 1}(1, proof);
    }

    function testIsolatedMultiMint() public {
        hoax(address(1337), address(1337));
        dazai.mintAllowlist{value: 10}(10, proof);
    }

    fallback() external payable {}
}
