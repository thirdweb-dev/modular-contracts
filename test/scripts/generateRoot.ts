import { MerkleTree } from "@thirdweb-dev/merkletree";
import { keccak256 } from "thirdweb/utils";

const members = [
  "0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd",
  "0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3",
  "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
];

const hashedLeafs = members.map(l => ethers.utils.solidityKeccak256(["address"], [l]));

const tree = new MerkleTree(hashedLeafs, keccak256, {
  sort: true,
  sortLeaves: true,
  sortPairs: true,
});

process.stdout.write(ethers.utils.defaultAbiCoder.encode(["bytes32"], [tree.getHexRoot()]));
