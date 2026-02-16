param(
  [string]$RPC = "https://ethereum-rpc.publicnode.com",
  [string]$CONTRACT = "0xF08E5Aec730BECb0833758dc565007E2C21F5dfb",
  [string]$DEPLOY_TX = "0x919f43629b268169c86997d23ae910d5a7928501b1cb1cd3dd204fecf240b2ff"
)

Write-Host "RPC: $RPC"
Write-Host "Contract: $CONTRACT"
Write-Host "Deploy TX: $DEPLOY_TX"

Write-Host "`n--- Contract bytecode (should NOT be 0x) ---"
cast code $CONTRACT --rpc-url $RPC

Write-Host "`n--- Receipt ---"
cast receipt $DEPLOY_TX --rpc-url $RPC
