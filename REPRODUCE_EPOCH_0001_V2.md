# Reproduce Epoch 0001 v2

This guide reproduces:

metrics:
outputs_differ = true  
consensus_violations = 0  
galileo_violations = 3  
delta_tier = NONE  

and verifies the Ethereum anchor.

---

## 1) Clone

git clone https://github.com/LHMisme420/vata-mainnet-evidence.git  
cd vata-mainnet-evidence  

---

## 2) Verify tuple + anchor

set RPC=https://ethereum-rpc.publicnode.com

powershell -ExecutionPolicy Bypass -File .\verify_tuple_field.ps1 `
  -EpochDir .\galileo\epoch_0001_v2 `
  -Field metrics `
  -VerifyAnchor

Expected:

ROOT OK  
ANCHOR VERIFIED  

---

## 3) Build soul_score circuit

circom circuits/soul_score.circom --r1cs --wasm --sym

cd soul_score_js

node generate_witness.js soul_score.wasm ..\circuits\examples\soul_score.json witness.wtns

snarkjs groth16 setup soul_score.r1cs powersOfTau28_hez_final_10.ptau soul_0000.zkey
snarkjs groth16 prove soul_0000.zkey witness.wtns proof.json public.json

cat public.json

Expected public output:

[97]

(100 - 3 violations = 97 soul score)

---

## 4) Meaning

You have now independently verified:

- On-chain anchored epoch data
- Metrics tuple
- ZK circuit reproducing one public value
