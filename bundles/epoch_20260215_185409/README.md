Epoch 20260215_185409

Expected metrics:
- outputs_differ: true
- consensus_violations: 0
- galileo_violations: 3
- delta_tier: NONE

Reproduce:

1. Hash clean_output.txt and poison_output.txt
2. Build Merkle tree over receipt.json + hashes
3. Compare Merkle root to merkle_root_v2.txt
4. Verify anchor using:

powershell -ExecutionPolicy Bypass -File verify_tuple_field.ps1 `
  -EpochDir .\bundles\epoch_20260215_185409 `
  -Field metrics `
  -VerifyAnchor
