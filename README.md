The first on-chain, reproducible Galileo defiance prover — Feb 2026


## Reproducible Evidence Bundles

This repository contains public bundles that allow independent reproduction of
anchored forensic tuples.

Latest bundle:

bundles/epoch_20260215_185409/

Expected:
- galileo_violations = 3
- consensus_violations = 0

Verify:

powershell -ExecutionPolicy Bypass -File verify_tuple_field.ps1 `
  -EpochDir bundles/epoch_20260215_185409 `
  -Field metrics `
  -VerifyAnchor


# Mainnet Evidence Anchor

TX: 0x946156a7dd9509c9668f5b9c58c1ad9ad2fc9f4f108b93aebe5549842c98f9f3
Block: 24464435
Anchored input (SHA-256): 0x3d4c16b14cf4ffc2a460a189efd52edecdf4fda8083ea834c6869aee8be3f205

## Verify on-chain
cast rpc --rpc-url https://ethereum-rpc.publicnode.com eth_getTransactionByHash 0x946156a7dd9509c9668f5b9c58c1ad9ad2fc9f4f108b93aebe5549842c98f9f3
cast receipt 0x946156a7dd9509c9668f5b9c58c1ad9ad2fc9f4f108b93aebe5549842c98f9f3 --rpc-url https://ethereum-rpc.publicnode.com

## Verify file
(Get-FileHash .\evidence\forensic_proof.bin -Algorithm SHA256).Hash
## Example Mainnet Anchor
TX: 0xYOUR_TX_HASH

Verify:
cast tx 0xYOUR_TX_HASH --rpc-url https://ethereum-rpc.publicnode.com

