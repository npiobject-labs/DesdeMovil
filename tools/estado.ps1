# ¿Está mi copia local al día? Solo lectura.
# Uso: pwsh -File tools\estado.ps1
#      pwsh -File tools\estado.ps1 -Proyecto MiProyecto -Root 'D:\dev\MiProyecto'
param(
  # PLANTILLA: cambia este valor por defecto al clonar la plantilla.
  [string]$Proyecto = 'DesdeMovil',

  [string]$Root = (Join-Path $env:USERPROFILE "C - Desarrollo\$Proyecto"),
  [string]$Rama = 'main'
)
$ErrorActionPreference = 'Stop'

$Repo = Join-Path $Root 'repo'
if (-not (Test-Path (Join-Path $Repo '.git'))) {
  Write-Host "$Proyecto : sin copia local en $Repo -> ejecuta tools\aterrizar.ps1"
  exit 1
}

git -C $Repo fetch --quiet origin
$local  = git -C $Repo rev-parse HEAD
$remote = git -C $Repo rev-parse "origin/$Rama"

if ($local -eq $remote) {
  Write-Host "$Proyecto : AL DIA ($($local.Substring(0,7)))"
} else {
  Write-Host "$Proyecto : DESACTUALIZADO -> local $($local.Substring(0,7)) / nube $($remote.Substring(0,7)) -> ejecuta tools\aterrizar.ps1"
}

$Drive = Join-Path $Root 'drive'
if (Test-Path $Drive) {
  $f = Get-ChildItem $Drive -Recurse -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if ($f) { Write-Host "  drive/: ultimo fichero $($f.Name) $($f.LastWriteTime)" }
}
