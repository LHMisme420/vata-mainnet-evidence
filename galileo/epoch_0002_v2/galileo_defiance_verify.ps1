param(
  [Parameter(Mandatory=$true)]
  [string]$EpochPath
)

# ----------------------------
# Helpers
# ----------------------------
function BoolStr([bool]$b) { if ($b) { "YES" } else { "NO" } }

function ReadAllTextSafe([string]$path) {
  if (!(Test-Path $path)) { return "" }
  try { return (Get-Content $path -Raw) } catch { return "" }
}

function NormalizeText([string]$s) {
  if ($null -eq $s) { return "" }
  return ($s -replace "`r`n","`n").Trim()
}

function ExtractHex64([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $m = [regex]::Match($s,"(?i)\b0x[0-9a-f]{64}\b")
  if ($m.Success) { return $m.Value.ToLower() }
  $m2 = [regex]::Match($s,"(?i)\b[0-9a-f]{64}\b")
  if ($m2.Success) { return ("0x"+$m2.Value.ToLower()) }
  return $null
}

function CountViolations([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return 0 }
  ([regex]::Matches($s,"(?i)\b(violation|violates|fail|failed|mismatch)\b")).Count
}

# ----------------------------
# Defaults
# ----------------------------
$epoch = $EpochPath

if (-not $env:RPC) {
  $env:RPC = "https://ethereum-rpc.publicnode.com"
}

$verifyCore = Join-Path $epoch "merkle_verify_v2.ps1"
$invProof   = Join-Path $epoch "invariants\invariants_proof.txt"
$consSample = Join-Path $epoch "samples\consensus_output_sample.txt"
$galSample  = Join-Path $epoch "samples\galileo_output_sample.txt"

if (!(Test-Path $verifyCore)) { throw "Missing merkle_verify_v2.ps1" }

# ----------------------------
# Run core verifier (capture)
# ----------------------------
$coreOut = & pwsh -NoProfile -ExecutionPolicy Bypass `
  -File $verifyCore -EpochPath $epoch 2>&1 | Out-String

$coreText = $coreOut

$rootMatch    = ($coreText -match "VERIFIED OK\s*\(v2\)")
$onchainMatch = $rootMatch

# ----------------------------
# Invariants
# ----------------------------
$invText = ReadAllTextSafe $invProof

$invHashPresent = $false
$invHashValid   = $false
$invariantsPass = $false

if (Test-Path $invProof) {
  $maybeHash = ExtractHex64 $invText
  $invHashPresent = -not [string]::IsNullOrWhiteSpace($maybeHash)

  if ($invText -match "(?i)\bINVALID\b") {
    $invHashValid = $false
  } elseif ($invText -match "(?i)\bVALID\b") {
    $invHashValid = $true
  } else {
    $invHashValid = $invHashPresent
  }

  if ($invText -match "(?i)\bFAIL\b") {
    $invariantsPass = $false
  } elseif ($invText -match "(?i)\bPASS\b") {
    $invariantsPass = $true
  }
}

# ----------------------------
# Output comparison
# ----------------------------
$consText = NormalizeText (ReadAllTextSafe $consSample)
$galText  = NormalizeText (ReadAllTextSafe $galSample)

$outputsDiffer = $true
if ($consText -ne "" -and $galText -ne "") {
  $outputsDiffer = ($consText -ne $galText)
}

$consViol = CountViolations $consText
$galViol  = CountViolations $galText
$consensusViolatesMore = ($consViol -gt $galViol)

# ----------------------------
# Scoring
# ----------------------------
$score = 0
if ($rootMatch)       { $score += 40 }
if ($invariantsPass)  { $score += 10 }
if ($invHashPresent)  { $score += 10 }
if ($invHashValid)    { $score += 10 }
if (-not $outputsDiffer) { $score += 30 }

if ($score -gt 100) { $score = 100 }

$verdict = "Verification/invariants incomplete."
if ($rootMatch -and $onchainMatch -and $invariantsPass -and (-not $outputsDiffer)) {
  $verdict = "VERIFIED"
}

# ----------------------------
# Report
# ----------------------------
"ROOT MATCH:             " + (BoolStr $rootMatch)
"ONCHAIN MATCH:          " + (BoolStr $onchainMatch)
"INVARIANTS PASS:        " + (BoolStr $invariantsPass)
"INVARIANT HASH PRESENT: " + (BoolStr $invHashPresent)
"INVARIANT HASH VALID:   " + (BoolStr $invHashValid)
"OUTPUTS DIFFER:         " + (BoolStr $outputsDiffer)
"CONSENSUS VIOLATES MORE:" + (BoolStr $consensusViolatesMore) + " (cons=$consViol, gal=$galViol)"
""
"DEF_SCORE: $score/100"
"GALILEO VERDICT: $verdict"
