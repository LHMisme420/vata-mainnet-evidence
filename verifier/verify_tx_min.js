import { ethers } from "ethers";

const rpc = process.argv[2];
const tx  = process.argv[3];

if (!rpc || !tx) {
  console.log("Usage: node verify_tx_min.js <RPC_URL> <TX_HASH>");
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(rpc);
const receipt = await provider.getTransactionReceipt(tx);

if (!receipt) {
  console.log("TX not found");
  process.exit(1);
}

console.log("Block :", receipt.blockNumber);
console.log("From  :", receipt.from);
console.log("To    :", receipt.to);
console.log("Status:", receipt.status === 1 ? "SUCCESS" : "FAIL");
