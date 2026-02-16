pragma circom 2.1.6;

/*
  Verifies:
  Poseidon(leaf, sibling) == root
  (depth-1 example)
*/

include "circomlib/poseidon.circom";

template MerkleInclusion() {
    signal input leaf;
    signal input sibling;
    signal input root;

    component h = Poseidon(2);
    h.inputs[0] <== leaf;
    h.inputs[1] <== sibling;

    root === h.out;
}

component main = MerkleInclusion();
