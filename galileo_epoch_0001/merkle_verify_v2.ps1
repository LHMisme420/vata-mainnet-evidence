param(
  [string]$EpochPath = ".",
  [string]$RPC = "https://ethereum-rpc.publicnode.com"
)

$epoch = Resolve-Path $EpochPath

$rootFile = Join-Path $epoch "merkle_root_v2.txt"
$txFile   = Join-Path $epoch "anchor_tx_v2.txt"
$tupleFile= Join-Path $epoch "tuple_v2.json"

if (!(Test-Path $rootFile)) { throw "Missing merkle_root_v2.txt" }
if (!(Test-Path $txFile))   { throw "Missing anchor_tx_v2.txt" }
if (!(Test-Path $tupleFile)){ throw "Missing tuple_v2.json" }

$root_local = (Get-Content $rootFile).Trim().ToLower()
$tx = (Get-Content $txFile).Trim()

if ($root_local.Length -ne 64) { throw "Local root length != 64" }
if ($tx -notmatch "^0x[a-fA-F0-9]{64}$") { throw "anchor_tx_v2.txt is not a tx hash" }

$root_recomputed = (Get-FileHash $tupleFile -Algorithm SHA256).Hash.ToLower()
if ($root_recomputed -ne $root_local) {
  throw "Root mismatch: tuple_v2.json hash != merkle_root_v2.txt`nrecomputed=$root_recomputed`nlocal=$root_local"
}

$txInfo = cast tx $tx --rpc-url $RPC
$inputLine = ($txInfo | Select-String -Pattern "input").ToString()
if (!$inputLine) { throw "Could not find 'input' in cast tx output" }

$onchain = ($inputLine -split "\s+")[-1].Trim().ToLower()
$expected = "0x" + $root_local

if ($onchain -ne $expected) {
  throw "On-chain calldata mismatch`nonchain=$onchain`nexpected=$expected"
}

"VERIFIED OK (v2)"
"epoch=" + $epoch
"tx=" + $tx
"root=" + $expected
