[CmdletBinding()]
param(
  [string]$RpcUrl = "https://ethereum-rpc.publicnode.com",
  [string]$TxHash = "0xae9a845605d9a445eb6710d259d1596baadc58a8d4daf1834e8506250dab9275",
  [string]$ReceiptPath = "./galileo/epoch_0001_v2/receipt.json",
  [string]$MerklePath  = "./galileo/epoch_0001_v2/merkle_root_v2.txt",
  [ValidateSet("auto","merkle-only","receipt+merkle")]
  [string]$Mode = "auto",
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

if (-not (Test-Path $MerklePath))  { Fail 2 "ERROR: merkle file not found:  $MerklePath" }
if ($TxHash -notmatch '^0x[0-9a-fA-F]{64}$') { Fail 2 "ERROR: TxHash must be 0x + 64 hex chars." }

$expected_merkle  = Normalize-Bytes32 ((Get-Content $MerklePath -Raw).Trim())
if (-not $expected_merkle) { Fail 2 "ERROR: merkle_root_v2.txt must be 64 hex chars (with or without 0x)." }

$expected_receipt = $null
if (Test-Path $ReceiptPath) {
  $expected_receipt = "0x" + (Get-FileHash $ReceiptPath -Algorithm SHA256).Hash.ToLower()
}

$input = (cast tx --rpc-url $RpcUrl $TxHash input | Out-String).Trim().ToLower()
if ($input -notmatch '^0x[0-9a-f]+$') { Fail 3 "ERROR: unexpected tx input response: $input" }

$hex = $input.Substring(2)
$len = $hex.Length

# Determine how many bytes32 words are present
$has1 = ($len -ge 64)
$has2 = ($len -ge 128)

if (-not $Quiet) {
  Write-Host "RPC     : $RpcUrl"
  Write-Host "TX      : $TxHash"
  Write-Host "MODE    : $Mode"
  Write-Host "RECEIPT : $ReceiptPath"
  Write-Host "MERKLE  : $MerklePath"
  Write-Host "TXINPUT_HEX_LEN: $len"
  Write-Host ""
  if ($expected_receipt) { Write-Host "expected_receipt=$expected_receipt" } else { Write-Host "expected_receipt=(missing locally; not required for merkle-only)" }
  Write-Host "expected_merkle =$expected_merkle"
  Write-Host ""
}

# Decode
$onchain_a = $null
$onchain_b = $null
if ($has1) { $onchain_a = "0x" + $hex.Substring(0,64) }
if ($has2) { $onchain_b = "0x" + $hex.Substring(64,64) }

# Auto mode: if only 1 word, treat it as merkle root anchor.
if ($Mode -eq "auto") {
  if ($has2) { $Mode = "receipt+merkle" } else { $Mode = "merkle-only" }
}

if ($Mode -eq "merkle-only") {
  if (-not $has1) { Fail 1 "ERROR: tx input too short to contain 1x bytes32." }
  if (-not $Quiet) { Write-Host "onchain_merkle =$onchain_a"; Write-Host "" }
  if ($expected_merkle -eq $onchain_a) {
    if (-not $Quiet) { Write-Host "PROOF VALID - MERKLE ROOT MATCHES MAINNET ANCHOR" }
    exit 0
  } else {
    if (-not $Quiet) { Write-Host "PROOF INVALID - MERKLE MISMATCH" }
    exit 1
  }
}

# receipt+merkle mode
if (-not $has2) { Fail 1 "ERROR: tx input too short to contain 2x bytes32." }
if (-not $expected_receipt) { Fail 2 "ERROR: receipt file not found (required for receipt+merkle mode): $ReceiptPath" }

$onchain_receipt = $onchain_a
$onchain_merkle  = $onchain_b

if (-not $Quiet) {
  Write-Host "onchain_receipt =$onchain_receipt"
  Write-Host "onchain_merkle  =$onchain_merkle"
  Write-Host ""
}

if ($expected_receipt -eq $onchain_receipt -and $expected_merkle -eq $onchain_merkle) {
  if (-not $Quiet) { Write-Host "PROOF VALID - RECEIPT SHA + MERKLE ROOT MATCH MAINNET ANCHOR" }
  exit 0
} else {
  if (-not $Quiet) { Write-Host "PROOF INVALID - MISMATCH" }
  exit 1
}
