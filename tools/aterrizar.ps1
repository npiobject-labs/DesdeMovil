# Aterrizaje nube -> PC. Idempotente y unidireccional. Sobrescribe la copia local sin preguntar.
# Uso: pwsh -File tools\aterrizar.ps1   (desde cualquier sitio; la raíz es la carpeta local del proyecto)
$ErrorActionPreference = 'Stop'
$Root  = 'C:\Users\fsant\C - Desarrollo\DesdeMovil'
$Repo  = Join-Path $Root 'repo'
$Remote = 'https://github.com/npiobject/DesdeMovil.git'
New-Item -ItemType Directory -Force -Path $Root | Out-Null
if (-not (Test-Path (Join-Path $Repo '.git'))) {
  git clone $Remote $Repo
} else {
  git -C $Repo fetch --prune origin
  git -C $Repo reset --hard origin/main
  git -C $Repo clean -fdx
}
$sha = git -C $Repo rev-parse --short HEAD
Write-Host "repo/ = origin/main @ $sha"
$Drive = Join-Path $Root 'drive'
if (Test-Path $Drive) { Write-Host "drive/ presente: $((Get-ChildItem $Drive -Recurse -File).Count) ficheros (sincronizado por Google Drive de escritorio)" }
else { Write-Host "drive/ no existe: crea la carpeta con Google Drive de escritorio apuntando a Mi unidad\DesdeMovil, o pide a Cowork que la vuelque." }
