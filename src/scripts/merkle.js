const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");
const { ethers } = require("ethers");

const getAddressTreeRoot = (addresses) => {
  const leafNodes = addresses.map((address) => keccak256(address));
  const tree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
  const root = tree.getHexRoot();
  return { root, tree };
};

const getAddressProof = (tree, address) => {
  return tree.getHexProof(keccak256(address));
};

const addressList = [
  "0x0000000000000000000000000000000000000539",
  "0x9af2e2b7e57c1cd7c68c5c3796d8ea67e0018db7",
  "0x9af2e2b7e57c1cd7c68c5c3796d8ea67e0018db7",
];

const { root, tree } = getAddressTreeRoot(addressList);
const proof = getAddressProof(
  tree,
  "0x0000000000000000000000000000000000000539"
);

const leaf = keccak256("0x0000000000000000000000000000000000000539");

console.log(tree.toString());
console.log("root", root);
console.log("proof", proof);
console.log("leaf", leaf);
console.log(tree.verify(proof, leaf, root));
