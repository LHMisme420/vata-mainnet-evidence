param(
    [Parameter(Mandatory=$true)]
    [string]$EpochPath
)

$epoch = $EpochPath

$rootFile  = Join-Path $epoch "merkle_root_v2.txt"
$tupleFile = Join-Path $epoch "tuple_v2.json"
$txFile    = Join-Path $epoch "anchor_tx_v2.txt"

if (!(Test-Path $rootFile))  { throw "Missing merkle_root_v2.txt" }
if (!(Test-Path $tupleFile)) { throw "Missing tuple_v2.json" }
if (!(Test-Path $txFile))    { throw "Missing anchor_tx_v2.txt" }

$root_local = (Get-Content $rootFile -Raw).Trim().ToLower()

if ($root_local.Length -ne 64) {
    throw "Local root length != 64"
}

# Recompute root from tuple file
$root_recomputed = (Get-FileHash $tupleFile -Algorithm SHA256).Hash.ToLower()

if ($root_recomputed -ne $root_local) {
    throw "Root mismatch: tuple_v2.json hash != merkle_root_v2.txt`nrecomputed=$root_recomputed`nlocal=$root_local"
}

# Load tx hash
$tx = (Get-Content $txFile -Raw).Trim()

if ($tx -notmatch "^0x[a-fA-F0-9]{64}$") {
    throw "anchor_tx_v2.txt is not a tx hash"
}

# Pull tx from chain
$txInfo = cast tx $tx --rpc-url $env:RPC

$inputLine = ($txInfo | Select-String -Pattern "input").ToString()

if (!$inputLine) {
    throw "Could not find 'input' in cast tx output"
}

$raw = ($inputLine -split '\s+')[1]
$expected = "0x" + $root_local

# ABI-aware decode
# If input = selector(8 hex) + 64 hex arg
if ($raw.Length -eq 74) {
    $arg = "0x" + $raw.Substring(10,64)
} else {
    $arg = $raw
}

if ($arg.ToLower() -ne $expected.ToLower()) {
    throw "On-chain calldata mismatch`nonchain=$arg`nexpected=$expected"
}

"VERIFIED OK (v2)"
"epoch=$epoch"
"tx=$tx"
"root=$expected"
