param(
  [Parameter(Mandatory=$true)][string]$EpochDir,
  [string]$RPC = "https://ethereum-rpc.publicnode.com"
)

$env:RPC = $RPC
$log = Join-Path $EpochDir "verify_log.txt"

powershell -ExecutionPolicy Bypass -File .\verify_tuple_field.ps1 `
  -EpochDir $EpochDir -Field metrics -VerifyAnchor | Tee-Object -FilePath $log
