param(
    [Parameter(Mandatory=$true)]
    [string]$EpochDir,

    [Parameter(Mandatory=$true)]
    [string]$Field,

    [switch]$VerifyAnchor
)

Write-Host "====================================="
Write-Host "VATA Tuple Field Verifier"
Write-Host "EpochDir: $EpochDir"
Write-Host "Field:    $Field"
Write-Host "====================================="

# -------------------------------
# Validate paths
# -------------------------------

if (-not (Test-Path $EpochDir)) {
    throw "Epoch directory not found: $EpochDir"
}

$receiptPath = Join-Path $EpochDir "receipt.json"
$rootPath    = Join-Path $EpochDir "merkle_root_v2.txt"

if (-not (Test-Path $receiptPath)) {
    throw "Missing receipt.json"
}

if (-not (Test-Path $rootPath)) {
    throw "Missing merkle_root_v2.txt"
}

# -------------------------------
# Load receipt
# -------------------------------

$receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json

if (-not ($receipt.PSObject.Properties.Name -contains $Field)) {
    throw "Field '$Field' not found in receipt.json"
}

Write-Host ""
Write-Host "FIELD VALUE:"
Write-Host $receipt.$Field
Write-Host ""

# -------------------------------
# Load local Merkle root
# -------------------------------

$localRoot = ("0x" + (Get-Content $rootPath -Raw).Trim().ToLower())

Write-Host "LOCAL MERKLE ROOT:"
Write-Host $localRoot
Write-Host ""

# -------------------------------
# Anchor verification
# -------------------------------

if ($VerifyAnchor) {

    Write-Host "Running Anchor Verification..."
    Write-Host ""

    if (-not ($receipt.PSObject.Properties.Name -contains "anchor_tx")) {
        throw "receipt.json missing anchor_tx"
    }

    if (-not $env:RPC) {
        throw "RPC environment variable not set"
    }

    $tx = $receipt.anchor_tx

    Write-Host "Anchor TX:"
    Write-Host $tx
    Write-Host ""

    $txInputLine = cast tx $tx --rpc-url $env:RPC | Select-String "input"

    if (-not $txInputLine) {
        throw "Could not retrieve transaction input"
    }

    # Extract raw input hex (0x...) from the cast output line
    $inputHex = ($txInputLine -replace "input\s+", "").Trim().ToLower()

    # Normalize: ensure it starts with 0x
    if (-not $inputHex.StartsWith("0x")) {
        $inputHex = "0x" + $inputHex
    }

    # ABI note: calldata = 4-byte selector + 32-byte arg for anchor(bytes32).
    # We want the LAST 32 bytes (64 hex chars) as the merkle root.
    $hexNoPrefix = $inputHex.Substring(2)
    if ($hexNoPrefix.Length -lt 64) {
        throw "On-chain input too short to contain bytes32 root"
    }

    $onchainRoot = "0x" + $hexNoPrefix.Substring($hexNoPrefix.Length - 64, 64)

    Write-Host "ONCHAIN ROOT:"
    Write-Host $onchainRoot
    Write-Host ""

    if ($localRoot -ne $onchainRoot) {
        throw "Anchor verification failed"
    }

    Write-Host "ROOT OK"
    Write-Host "ANCHOR VERIFIED"
}

Write-Host ""
Write-Host "Verification complete."
Write-Host "====================================="
