# Aterrizaje nube -> PC. Idempotente y unidireccional. Sobrescribe la copia local sin preguntar.
# Uso: pwsh -File tools\aterrizar.ps1
#      pwsh -File tools\aterrizar.ps1 -Proyecto MiProyecto -Owner miusuario
#      pwsh -File tools\aterrizar.ps1 -Root 'D:\dev\MiProyecto'
param(
  # PLANTILLA: cambia estos dos valores por defecto al clonar la plantilla.
  [string]$Proyecto = 'DesdeMovil',
  [string]$Owner    = 'npiobject',

  [string]$Remote   = "https://github.com/$Owner/$Proyecto.git",
  [string]$Root     = (Join-Path $env:USERPROFILE "C - Desarrollo\$Proyecto"),
  [string]$Rama     = 'main'
)
$ErrorActionPreference = 'Stop'

$Repo = Join-Path $Root 'repo'
New-Item -ItemType Directory -Force -Path $Root | Out-Null

if (-not (Test-Path (Join-Path $Repo '.git'))) {
  git clone --branch $Rama $Remote $Repo
} else {
  git -C $Repo fetch --prune origin
  git -C $Repo reset --hard "origin/$Rama"
  git -C $Repo clean -fdx
}

$sha = git -C $Repo rev-parse --short HEAD
Write-Host "$Proyecto : repo/ = origin/$Rama @ $sha"
Write-Host "  local  : $Repo"
Write-Host "  remoto : $Remote"

$Drive = Join-Path $Root 'drive'
if (Test-Path $Drive) {
  Write-Host "  drive/ : $((Get-ChildItem $Drive -Recurse -File).Count) ficheros (sincronizado por Google Drive de escritorio)"
} else {
  Write-Host "  drive/ : no existe. Crea la carpeta con Google Drive de escritorio apuntando a 'Mi unidad\$Proyecto', o pide a Cowork que la vuelque."
}
