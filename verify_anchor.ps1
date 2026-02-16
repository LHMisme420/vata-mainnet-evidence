[CmdletBinding()]
param(
  [string]$RpcUrl = "https://ethereum-rpc.publicnode.com",
  [string]$TxHash = "0xfce1402c3c4609910976b5be0dea00ccbe7a61d548fbc9b65ed748b45a02daa9",
  [string]$ReceiptPath = "./galileo/epoch_0001_v2/receipt.json",
  [string]$MerklePath  = "./galileo/epoch_0001_v2/merkle_root_v2.txt",
  [switch]$Quiet
)

function Fail([int]$Code, [string]$Msg) { if (-not $Quiet) { Write-Host $Msg }; exit $Code }

try { $null = Get-Command cast -ErrorAction Stop } catch { Fail 3 "ERROR: 'cast' not found in PATH." }

function Normalize-Bytes32([string]$s) {
  if (-not $s) { return $null }
  $t = $s.Trim().ToLower()
  if ($t.StartsWith("0x")) { $t = $t.Substring(2) }
  if ($t -notmatch '^[0-9a-f]{64}$') { return $null }
  return "0x$t"
}

if (-not (Test-Path $ReceiptPath)) { Fail 2 "ERROR: receipt file not found: $ReceiptPath" }
if (-not (Test-Path $MerklePath))  { Fail 2 "ERROR: merkle file not found:  $MerklePath" }
if ($TxHash -notmatch '^0x[0-9a-fA-F]{64}$') { Fail 2 "ERROR: TxHash must be 0x + 64 hex chars." }

$expected_receipt = "0x" + (Get-FileHash $ReceiptPath -Algorithm SHA256).Hash.ToLower()
$expected_merkle  = Normalize-Bytes32 ((Get-Content $MerklePath -Raw).Trim())
if (-not $expected_merkle) { Fail 2 "ERROR: merkle_root_v2.txt must be 64 hex chars (with or without 0x)." }

$input = (cast tx --rpc-url $RpcUrl $TxHash input | Out-String).Trim().ToLower()
if ($input -notmatch '^0x[0-9a-f]+$') { Fail 3 "ERROR: unexpected tx input response: $input" }

$h = $input.Substring(2)
if ($h.Length -lt 128) { Fail 1 "ERROR: tx input too short to contain 2x bytes32." }

$onchain_receipt = "0x" + $h.Substring(0,64)
$onchain_merkle  = "0x" + $h.Substring(64,64)

if (-not $Quiet) {
  Write-Host "RPC     : $RpcUrl"
  Write-Host "TX      : $TxHash"
  Write-Host "RECEIPT : $ReceiptPath"
  Write-Host "MERKLE  : $MerklePath"
  Write-Host ""
  Write-Host "expected_receipt=$expected_receipt"
  Write-Host "onchain_receipt =$onchain_receipt"
  Write-Host "expected_merkle =$expected_merkle"
  Write-Host "onchain_merkle  =$onchain_merkle"
  Write-Host ""
}

if ($expected_receipt -eq $onchain_receipt -and $expected_merkle -eq $onchain_merkle) {
  if (-not $Quiet) { Write-Host "PROOF VALID - FILES MATCH MAINNET ANCHOR" }
  exit 0
} else {
  if (-not $Quiet) { Write-Host "PROOF INVALID - MISMATCH" }
  exit 1
}
