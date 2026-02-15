param(
  [string]$EpochPath = ".",
  [string]$RPC = "https://ethereum-rpc.publicnode.com"
)

$epoch = Resolve-Path $EpochPath

# --- paths ---
$verifyCore = Join-Path $epoch "merkle_verify_v2.ps1"

$invResult  = Join-Path $epoch "invariants\invariants_result.json"
$invProof   = Join-Path $epoch "invariants\invariants_proof.txt"
$invHash    = Join-Path $epoch "hashes\invariants_satisfied_proof.hash"

$consSample = Join-Path $epoch "samples\consensus_output_sample.txt"
$galSample  = Join-Path $epoch "samples\galileo_output_sample.txt"

$invCfgPath = Join-Path $epoch "invariants\invariants.json"

# --- helpers ---
function BoolStr($b) { if ($b) { "YES" } else { "NO" } }
function SafeReadText($p) { if (Test-Path $p) { (Get-Content $p -Raw) } else { "" } }

# --- run core verifier first (authoritative) ---
if (!(Test-Path $verifyCore)) { throw "Missing merkle_verify_v2.ps1 in $epoch" }

$coreOut  = & pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyCore -EpochPath $epoch -RPC $RPC 2>&1
$coreText = ($coreOut | Out-String)

$rootMatch    = $coreText -match "VERIFIED OK \(v2\)"
$onchainMatch = $rootMatch  # core verifier already checks on-chain calldata == root

# --- invariants pass signal (from invariants_result.json) ---
$invPass = $false
if (Test-Path $invResult) {
  try {
    $inv = (Get-Content $invResult -Raw | ConvertFrom-Json)
    $invPass = [bool]$inv.pass
  } catch { $invPass = $false }
}

# --- invariant proof hash presence + consistency ---
$invHashPresent = $false
$invHashConsistent = $false
if ((Test-Path $invHash) -and (Test-Path $invProof)) {
  $hFile = (Get-Content $invHash -Raw).Trim().ToLower()
  if ($hFile -match "^[0-9a-f]{64}$") { $invHashPresent = $true }
  $hCalc = (Get-FileHash $invProof -Algorithm SHA256).Hash.ToLower()
  $invHashConsistent = ($hCalc -eq $hFile)
}

# --- outputs differ (defiance signal) ---
$consText = SafeReadText $consSample
$galText  = SafeReadText $galSample
$outputsDiffer = ($consText.Trim() -ne $galText.Trim()) -and ($consText.Trim().Length -gt 0) -and ($galText.Trim().Length -gt 0)

# --- "consensus violated invariants" heuristic (must_not_include scan) ---
$consViolations = 0
$galViolations  = 0
$consensusViolatesMore = $false

if (Test-Path $invCfgPath) {
  try {
    $cfg = (Get-Content $invCfgPath -Raw | ConvertFrom-Json)
    $mustNot = @()
    if ($cfg.PSObject.Properties.Name -contains "must_not_include") { $mustNot = @($cfg.must_not_include) }

    if ($mustNot.Count -gt 0) {
      foreach ($p in $mustNot) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($consText.ToLower().Contains($p.ToLower())) { $consViolations++ }
        if ($galText.ToLower().Contains($p.ToLower()))  { $galViolations++ }
      }
      $consensusViolatesMore = ($consViolations -gt $galViolations)
    }
  } catch {
    $consViolations = 0
    $galViolations  = 0
    $consensusViolatesMore = $false
  }
}

# --- Defiance Score (0–100) ---
$score = 0

# Integrity (80 max)
if ($rootMatch)    { $score += 40 }
if ($onchainMatch) { $score += 40 }

# Invariants integrity (20 max)
if ($invPass)           { $score += 10 }
if ($invHashPresent)    { $score += 5 }
if ($invHashConsistent) { $score += 5 }

# Defiance indicators (bonus; capped)
if ($outputsDiffer)         { $score += 10 }
if ($consensusViolatesMore) { $score += 10 }

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

if ($score -ge 90) {
  "GALILEO VERDICT: Integrity + invariants VERIFIED. Defiance indicators STRONG (zk-proof pending)."
} elseif ($score -ge 75) {
  "GALILEO VERDICT: Integrity + invariants VERIFIED. Defiance indicators PRESENT (zk-proof pending)."
} elseif ($score -ge 50) {
  "GALILEO VERDICT: Integrity VERIFIED, defiance unclear/weak."
} else {
  "GALILEO VERDICT: Verification/invariants incomplete."
}
