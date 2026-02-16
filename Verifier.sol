// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Verifier {
    event ProofAnchored(bytes32 indexed root);

    function anchor(bytes32 root) external {
        emit ProofAnchored(root);
    }
}
