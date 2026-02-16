param(
  [string]$EpochPath = ".",
  [string]$RPC = "https://ethereum-rpc.publicnode.com"
)

$epoch = Resolve-Path $EpochPath

$rootFile = Join-Path $epoch "merkle_root.txt"
$txFile   = Join-Path $epoch "anchor_tx.txt"
$tupleFile= Join-Path $epoch "tuple.json"

if (!(Test-Path $rootFile)) { throw "Missing merkle_root.txt" }
if (!(Test-Path $txFile))   { throw "Missing anchor_tx.txt" }
if (!(Test-Path $tupleFile)){ throw "Missing tuple.json" }

$root_local = (Get-Content $rootFile).Trim()
$tx = (Get-Content $txFile).Trim()

if ($root_local.Length -ne 64) { throw "Local root length != 64" }
if ($tx -notmatch "^0x[a-fA-F0-9]{64}$") { throw "anchor_tx.txt does not look like a tx hash" }

# recompute root from tuple.json
$root_recomputed = (Get-FileHash $tupleFile -Algorithm SHA256).Hash.ToLower()

if ($root_recomputed -ne $root_local.ToLower()) {
  throw "Root mismatch: tuple.json hash != merkle_root.txt`nrecomputed=$root_recomputed`nlocal=$root_local"
}

# fetch tx input and compare
$txInfo = cast tx $tx --rpc-url $RPC
$inputLine = ($txInfo | Select-String -Pattern "input").ToString()

if (!$inputLine) { throw "Could not find 'input' in cast tx output" }

$onchain = ($inputLine -split "\s+")[-1].Trim()
$expected = "0x" + $root_local.ToLower()

if ($onchain.ToLower() -ne $expected) {
  throw "On-chain calldata mismatch`nonchain=$onchain`nexpected=$expected"
}

"VERIFIED OK"
"epoch=" + $epoch
"tx=" + $tx
"root=" + $expected
