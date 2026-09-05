# ¿Está mi copia local al día? Solo lectura.
$Repo = 'C:\Users\fsant\C - Desarrollo\DesdeMovil\repo'
if (-not (Test-Path (Join-Path $Repo '.git'))) { Write-Host 'Sin copia local: ejecuta tools\aterrizar.ps1'; exit 1 }
git -C $Repo fetch --quiet origin
$local  = git -C $Repo rev-parse HEAD
$remote = git -C $Repo rev-parse origin/main
if ($local -eq $remote) { Write-Host "AL DIA ($($local.Substring(0,7)))" } else { Write-Host "DESACTUALIZADO: local $($local.Substring(0,7)) / nube $($remote.Substring(0,7)) -> ejecuta tools\aterrizar.ps1" }
$Drive = 'C:\Users\fsant\C - Desarrollo\DesdeMovil\drive'
if (Test-Path $Drive) { $f = Get-ChildItem $Drive -Recurse -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1; Write-Host "drive/: ultimo fichero $($f.Name) $($f.LastWriteTime)" }
