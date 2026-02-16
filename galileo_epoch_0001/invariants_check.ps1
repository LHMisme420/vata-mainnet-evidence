param(
  [string]$EpochPath = "."
)

$epoch = Resolve-Path $EpochPath

$galileoOut = Join-Path $epoch "outputs\galileo_output.txt"
$consensusOut = Join-Path $epoch "outputs\consensus_output.txt"
$invJson = Join-Path $epoch "invariants\invariants.json"

if (!(Test-Path $galileoOut))  { throw "Missing outputs\galileo_output.txt" }
if (!(Test-Path $consensusOut)) { throw "Missing outputs\consensus_output.txt" }
if (!(Test-Path $invJson))     { throw "Missing invariants\invariants.json" }

$g = (Get-Content $galileoOut -Raw)
$c = (Get-Content $consensusOut -Raw)
$inv = Get-Content $invJson -Raw | ConvertFrom-Json

# Helpers
function NowUtcIso() { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function HasAny($text, [string[]]$phrases) {
  foreach ($p in $phrases) { if ($text -match [regex]::Escape($p)) { return $true } }
  return $false
}
function HasAll($text, [string[]]$phrases) {
  foreach ($p in $phrases) { if ($text -notmatch [regex]::Escape($p)) { return $false } }
  return $true
}

# Rule sets (simple, extendable)
$contradictionPairs = @(
  @{ a="energy can be created from nothing"; b="energy cannot be created from nothing" },
  @{ a="perpetual motion is possible"; b="perpetual motion is impossible" },
  @{ a="entropy decreases naturally"; b="entropy does not decrease in a closed system" }
)

$failures = @()
$checks = @()

# Check: must_include / must_not_include
$mustInclude = @()
$mustNotInclude = @()
if ($inv.PSObject.Properties.Name -contains "must_include")   { $mustInclude = @($inv.must_include) }
if ($inv.PSObject.Properties.Name -contains "must_not_include"){ $mustNotInclude = @($inv.must_not_include) }

if ($mustInclude.Count -gt 0) {
  $ok = HasAll $g $mustInclude
  $checks += @{ name="must_include"; ok=$ok; details=("required=" + ($mustInclude -join "; ")) }
  if (-not $ok) { $failures += "Missing required phrases: $($mustInclude -join ', ')" }
}

if ($mustNotInclude.Count -gt 0) {
  $ok = -not (HasAny $g $mustNotInclude)
  $checks += @{ name="must_not_include"; ok=$ok; details=("banned=" + ($mustNotInclude -join "; ")) }
  if (-not $ok) { $failures += "Contains banned phrase(s) from must_not_include." }
}

# Check: non-contradiction (simple pair scan)
if (($inv.PSObject.Properties.Name -contains "non_contradiction") -and ($inv.non_contradiction -eq $true)) {
  $pairViolations = @()
  foreach ($p in $contradictionPairs) {
    if (($g.ToLower().Contains($p.a)) -and ($g.ToLower().Contains($p.b))) {
      $pairViolations += "$($p.a) AND $($p.b)"
    }
  }
  $ok = ($pairViolations.Count -eq 0)
  $checks += @{ name="non_contradiction_pairs"; ok=$ok; details=($pairViolations -join " | ") }
  if (-not $ok) { $failures += "Contradiction pairs found: $($pairViolations -join ' ; ')" }
}

# Check: energy conservation (minimal sanity: must not assert creation from nothing)
if (($inv.PSObject.Properties.Name -contains "energy_conservation") -and ($inv.energy_conservation -eq $true)) {
  $bad = @("energy can be created from nothing", "perpetual motion is possible")
  $ok = -not (HasAny $g $bad)
  $checks += @{ name="energy_conservation_sanity"; ok=$ok; details=("banned=" + ($bad -join "; ")) }
  if (-not $ok) { $failures += "Energy conservation sanity failed (claims creation/perpetual motion)." }
}

# Check: entropy non-decrease (minimal sanity)
if (($inv.PSObject.Properties.Name -contains "entropy_non_decrease") -and ($inv.entropy_non_decrease -eq $true)) {
  $bad = @("entropy decreases naturally", "entropy always decreases")
  $ok = -not (HasAny $g $bad)
  $checks += @{ name="entropy_non_decrease_sanity"; ok=$ok; details=("banned=" + ($bad -join "; ")) }
  if (-not $ok) { $failures += "Entropy sanity failed (claims entropy decreases)." }
}

# Check: predictive_power (basic: mentions conditions + constraint words)
if (($inv.PSObject.Properties.Name -contains "predictive_power") -and ($inv.predictive_power -eq $true)) {
  $need = @("closed system", "conservation")
  $ok = HasAny $g $need
  $checks += @{ name="predictive_power_min"; ok=$ok; details=("needs_any=" + ($need -join "; ")) }
  if (-not $ok) { $failures += "Predictive power min failed (missing 'closed system'/'conservation' signals)." }
}

# Compare vs consensus (optional signal: do they differ)
$differ = ($g.Trim() -ne $c.Trim())
$checks += @{ name="differs_from_consensus"; ok=$differ; details="galileo_output != consensus_output" }

$pass = ($failures.Count -eq 0)

# Write transcript proof
$proofPath = Join-Path $epoch "invariants\invariants_proof.txt"
$resultPath = Join-Path $epoch "invariants\invariants_result.json"

$hdr = @()
$hdr += "VATA Galileo Invariant Proof"
$hdr += "timestamp_utc: $(NowUtcIso)"
$hdr += "epoch_path: $epoch"
$hdr += "galileo_output_bytes: $([Text.Encoding]::UTF8.GetByteCount($g))"
$hdr += "consensus_output_bytes: $([Text.Encoding]::UTF8.GetByteCount($c))"
$hdr += ""

$body = @()
$body += "CHECKS:"
foreach ($ch in $checks) {
  $body += ("- " + $ch.name + " => " + (if ($ch.ok) {"OK"} else {"FAIL"}) + (if ($ch.details) {" | " + $ch.details} else {""}))
}
$body += ""
$body += "VERDICT: " + (if ($pass) {"PASS"} else {"FAIL"})
if (-not $pass) {
  $body += "FAILURES:"
  foreach ($f in $failures) { $body += ("- " + $f) }
}
$body += ""
$body += "GALILEO_OUTPUT (verbatim):"
$body += $g

($hdr + $body) -join "`r`n" | Set-Content $proofPath -Encoding UTF8

# Machine-readable result
$result = @{
  pass = $pass
  timestamp_utc = NowUtcIso
  checks = $checks
  failures = $failures
}
$result | ConvertTo-Json -Depth 10 | Set-Content $resultPath -Encoding UTF8

# Hash the proof transcript
$hashDir = Join-Path $epoch "hashes"
if (!(Test-Path $hashDir)) { New-Item -ItemType Directory -Path $hashDir | Out-Null }

$proofHash = (Get-FileHash $proofPath -Algorithm SHA256).Hash.ToLower()
$proofHash | Set-Content (Join-Path $hashDir "invariants_satisfied_proof.hash")

"INVARIANTS CHECK COMPLETE"
"pass=$pass"
"proof_hash=$proofHash"
"proof_file=$proofPath"
"result_file=$resultPath"
