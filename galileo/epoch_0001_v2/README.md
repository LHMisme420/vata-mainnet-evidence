# VATA Galileo Epoch 0001 (v2) — Mainnet-Verifiable Invariants Receipt

This bundle is a minimal, reproducible “Galileo receipt”:
- A poisoned/biased input context is recorded
- A consensus baseline output is recorded
- A Galileo output is recorded
- An invariant-evaluation transcript is produced and hashed
- A Merkle root commits to the tuple and is anchored on Ethereum mainnet

## What’s anchored

**Ethereum Mainnet TX (v2):**
0xae9a845605d9a445eb6710d259d1596baadc58a8d4daf1834e8506250dab9275

**Anchored calldata (Merkle root v2):**
0x46e67fc467906ee7271dfb963fce764c7775911d1b297dfbea713fedada6f1d0

## The 5-tuple committed by tuple_v2.json

`tuple_v2.json` commits to:

- `polluted_input_hash`
- `consensus_output_hash`
- `galileo_output_hash`
- `invariants_satisfied_proof` (SHA256 of invariants proof transcript)
- `zk_proof_of_reasoning` (placeholder in this epoch; zk comes in Phase 2)

`merkle_root_v2.txt` is SHA256(tuple_v2.json).

## Invariants (what they mean here)

In this epoch, invariants are checked via a human-auditable transcript:

- **Non-contradiction:** output should not contain mutually contradictory claims.
- **Energy conservation sanity:** must not assert creation from nothing / perpetual motion.
- **Entropy sanity:** must not claim entropy “naturally decreases” in a closed system.
- **Predictive power (minimal):** output should reference “closed system” / “conservation”.

Full transcript:
- `invariants/invariants_proof.txt`

Result JSON:
- `invariants/invariants_result.json`

Invariant proof hash (committed in tuple_v2.json):
- `hashes/invariants_satisfied_proof.hash`

## Quickstart (verify in < 5 minutes)

Requirements:
- PowerShell (pwsh)
- Foundry `cast` installed and on PATH

Run:

```powershell
pwsh .\merkle_verify_v2.ps1 -EpochPath .
