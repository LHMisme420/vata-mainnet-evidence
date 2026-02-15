param(
  [string]$EpochPath = ".",
  [string]$RPC = "https://ethereum-rpc.publicnode.com"
)

$epoch = Resolve-Path $EpochPath

# --- paths ---
$verifyCore = Join-Path $epoch "merkle_verify_v2.ps1"
$tupleFile  = Join-Path $epoch "tuple_v2.json"
$rootFile   = Join-Path $epoch "merkle_root_v2.txt"
$txFile     = Join-Path $epoch "anchor_tx_v2.txt"

$invResult  = Join-Path $epoch "invariants\invariants_result.json"
$invProof   = Join-Path $epoch "invariants\invariants_proof.txt"
$invHash    = Join-Path $epoch "hashes\invariants_satisfied_proof.hash"

$consSample = Join-Path $epoch "samples\consensus_output_sample.txt"
$galSample  = Join-Path $epoch "samples\galileo_output_sample.txt"

# --- helpers ---
function BoolStr($b) { if ($b) { "YES" } else { "NO" } }
function SafeReadText($p) { if (Test-Path $p) { (Get-Content $p -Raw) } else { "" } }
function SafeReadTrim($p) { if (Test-Path $p) { (Get-Content $p -Raw).Trim() } else { "" } }

# --- run core verifier first (authoritative) ---
if (!(Test-Path $verifyCore)) { throw "Missing merkle_verify_v2.ps1" }

$coreOut = & pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyCore -EpochPath $epoch -RPC $RPC 2>&1
$coreText = ($coreOut | Out-String)

$rootMatch   = $coreText -match "VERIFIED OK \(v2\)"
$onchainMatch= $rootMatch  # core verifier already checks on-chain calldata == root

# --- compute additional signals ---
$invPass = $false
if (Test-Path $invResult) {
  try {
    $inv = (Get-Content $invResult -Raw | ConvertFrom-Json)
    $invPass = [bool]$inv.pass
  } catch { $invPass = $false }
}

# invariant proof hash presence + consistency
$invHashPresent = $false
$invHashConsistent = $false
if ((Test-Path $invHash) -and (Test-Path $invProof)) {
  $hFile = (Get-Content $invHash -Raw).Trim().ToLower()
  if ($hFile -match "^[0-9a-f]{64}$") { $invHashPresent = $true }
  $hCalc = (Get-FileHash $invProof -Algorithm SHA256).Hash.ToLower()
  $invHashConsistent = ($hCalc -eq $hFile)
}

# outputs differ (defiance signal)
$consText = SafeReadText $consSample
$galText  = SafeReadText $galSample
$outputsDiffer = ($consText.Trim() -ne $galText.Trim()) -and ($consText.Trim().Length -gt 0) -and ($galText.Trim().Length -gt 0)

# optional: "consensus violated invariants" heuristic (simple keyword scan)
# If invariants.json includes must_not_include phrases, we test consensus contains any and galileo does not.
$mustNot = @()
$invCfgPath = Join-Path $epoch "invariants\invariants.json"
if (Test-Path $invCfgPath) {
  try {
    $cfg = (Get-Content $invCfgPath -Raw | ConvertFrom-Json)
    if ($cfg.PSObject.Properties.Name -contains "must_not_include") { $mustNot = @($cfg.must_not_include) }
  } catch {}
}

$consViolations = 0
$galViolations  = 0
if ($mustNot.Count -gt 0) {
  foreach ($p in $mustNot) {
    if ($p -and ($consText.ToLower().Contains($p.ToLower()))) { $consViolations++ }
    if ($p -and ($galText.ToLower().Contains($p.ToLower())))  { $galViolations++ }
  }
}
$consensusViolatesMore = ($consViolations -gt $galViolations)

# --- Defiance Score (0–100) ---
# 70 points = integrity (root/onchain + invariant proof integrity)
# 30 points = defiance indicators (different outputs + consensus violates more)
$score = 0
$score += (if ($rootMatch) { 35 } else { 0 })
$score += (if ($onchainMatch) { 35 } else { 0 })

# Invariants: pass + hash present + hash consistent
$score += (if ($invPass) { 10 } else { 0 })
$score += (if ($invHashPresent) { 5 } else { 0 })
$score += (if ($invHashConsistent) { 5 } else { 0 })

# Defiance indicators
$score += (if ($outputsDiffer) { 20 } else { 0 })
$score += (if ($consensusViolatesMore) { 10 } else { 0 })

if ($score -gt 100) { $score = 100 }

# --- print summary ---
"ROOT MATCH:             " + (BoolStr $rootMatch)
"ONCHAIN MATCH:          " + (BoolStr $onchainMatch)
"INVARIANTS PASS:        " + (BoolStr $invPass)
"INVARIANT HASH PRESENT: " + (BoolStr $invHashPresent)
"INVARIANT HASH VALID:   " + (BoolStr $invHashConsistent)
"OUTPUTS DIFFER:         " + (BoolStr $outputsDiffer)
"CONSENSUS VIOLATES MORE:" + (BoolStr $consensusViolatesMore) + " (cons=$consViolations, gal=$galViolations)"
""
"DEF_SCORE: $score/100"
if ($score -ge 80) {
  "GALILEO VERDICT: Defiance indicators STRONG (zk-proof pending)."
} elseif ($score -ge 60) {
  "GALILEO VERDICT: Defiance indicators PRESENT (zk-proof pending)."
} elseif ($score -ge 40) {
  "GALILEO VERDICT: Integrity OK, defiance weak/unclear."
} else {
  "GALILEO VERDICT: Verification/invariants incomplete."
}
