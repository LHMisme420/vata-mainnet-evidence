param([string]$LeavesPath)

$leaves = Get-Content $LeavesPath | Where-Object { $_ -match "^[a-fA-F0-9]{64}$" } |
  ForEach-Object { $_.ToLower() }

if ($leaves.Count -lt 1) { throw "No leaves" }

function Sha256Hex([byte[]]$bytes) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
}

$layer = $leaves
while ($layer.Count -gt 1) {
  $next = @()
  for ($i=0; $i -lt $layer.Count; $i+=2) {
    $a = $layer[$i]
    $b = if ($i+1 -lt $layer.Count) { $layer[$i+1] } else { $layer[$i] } # duplicate last
    $bytes = [byte[]]::new(64)
    [Buffer]::BlockCopy(([byte[]]($a -split "([0-9a-f]{2})" | ? {$_} | % {[Convert]::ToByte($_,16)})),0,$bytes,0,32)
    [Buffer]::BlockCopy(([byte[]]($b -split "([0-9a-f]{2})" | ? {$_} | % {[Convert]::ToByte($_,16)})),0,$bytes,32,32)
    $next += (Sha256Hex $bytes)
  }
  $layer = $next
}

$layer[0]
