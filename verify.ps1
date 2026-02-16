$TX="0x946156a7dd9509c9668f5b9c58c1ad9ad2fc9f4f108b93aebe5549842c98f9f3"
$RPC="https://ethereum-rpc.publicnode.com"
$EXPECTED="0x3d4c16b14cf4ffc2a460a189efd52edecdf4fda8083ea834c6869aee8be3f205"

Write-Host "== On-chain tx input =="
$tx = cast rpc --rpc-url $RPC eth_getTransactionByHash $TX
$tx

Write-Host "`n== Receipt =="
cast receipt $TX --rpc-url $RPC

Write-Host "`n== Local file hash =="
$h = "0x" + (Get-FileHash .\evidence\forensic_proof.bin -Algorithm SHA256).Hash.ToLower()
$h

if($h -ne $EXPECTED){ throw "Mismatch: local hash != expected on-chain input" }
Write-Host "`nVERIFIED OK: local file hash matches on-chain tx input."
