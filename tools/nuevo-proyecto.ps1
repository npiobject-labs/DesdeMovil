<#
.SYNOPSIS
  Crea un proyecto nuevo en npiobject-labs de una sola vez: repo desde la
  plantilla, inicializacion, Pages, carpeta de Drive, app de Fly y CLAUDE.md
  con los parametros anotados.

.EXAMPLE
  .\nuevo-proyecto.ps1 inversion
  .\nuevo-proyecto.ps1 casaverde -SinDrive
  .\nuevo-proyecto.ps1 pruebax -SinFly -SinDrive      # solo repo + Pages
  .\nuevo-proyecto.ps1 pruebax -Eliminar              # borra repo, app de Fly y carpeta de Drive
  .\nuevo-proyecto.ps1 pruebax -Eliminar -Forzar      # sin pedir confirmacion

.NOTES
  Requisitos (una sola vez):
    winget install GitHub.cli ; gh auth login   (scopes: repo, workflow)
    git con credenciales para github.com (ya las tienes: los push van desde PowerShell)
    Drive: Apps Script "drive-carpeta.gs" publicado como aplicacion web y
           $env:DESDEMOVIL_DRIVE_WEBAPP / $env:DESDEMOVIL_DRIVE_TOKEN definidos
           (o pasa -DriveWebApp / -DriveToken). Sin ellos, Drive se omite.
    Fly: opcional. Si flyctl esta en el PATH y autenticado (flyctl auth login),
           la app se crea aqui y se detecta al momento si el nombre ya esta
           cogido. Si no, la crea deploy.yml.
    -Eliminar: gh necesita el scope delete_repo (gh auth refresh -s delete_repo);
           flyctl obligatorio para destruir la app; la carpeta de Drive va a la
           papelera (recuperable 30 dias), no se borra en el acto.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)][string]$Nombre,
  [string]$Owner       = "npiobject-labs",
  [string]$Plantilla   = "npiobject-labs/DesdeMovil",
  [string]$FlyOrg      = "desdemovil",
  [string]$DriveWebApp = $env:DESDEMOVIL_DRIVE_WEBAPP,
  [string]$DriveToken  = $env:DESDEMOVIL_DRIVE_TOKEN,
  [string]$Descripcion = "",
  [string]$GitEmail    = "",
  [switch]$SinDrive,
  [switch]$SinFly,
  [switch]$Eliminar,
  [switch]$Forzar,
  [int]$TimeoutMin     = 10
)

# "Continue" a proposito: en Windows PowerShell 5.1, con "Stop", cualquier
# linea que un comando nativo (gh, git, flyctl) escriba en stderr con 2>&1 se
# convierte en error terminal. Los fallos se comprueban con $LASTEXITCODE.
$ErrorActionPreference = "Continue"
$repo = "$Owner/$Nombre"
$inicio = Get-Date

function Paso([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok([string]$t)   { Write-Host "   OK  $t" -ForegroundColor Green }
function Aviso([string]$t){ Write-Host "   !!  $t" -ForegroundColor Yellow }
function Falla([string]$t){ Write-Host "   XX  $t" -ForegroundColor Red; exit 1 }

# gh devuelve JSON; esta funcion lo parsea y aborta si gh fallo.
function GhJson([string[]]$a) {
  $out = & gh @a 2>&1
  if ($LASTEXITCODE -ne 0) { throw "gh $($a -join ' ') -> $out" }
  if (-not $out) { return $null }
  return ($out | Out-String | ConvertFrom-Json)
}

# Espera a que el ultimo run de un workflow (creado despues de $desde) termine.
function Wait-Run([string]$workflow, [datetime]$desde, [int]$minutos = 10) {
  $limite = (Get-Date).AddMinutes($minutos)
  $run = $null
  while ((Get-Date) -lt $limite) {
    # El repo recien creado desde plantilla tarda unos segundos en tener contenido:
    # hasta entonces gh responde 404 "workflow not found". Se reintenta.
    try {
      $lista = GhJson @("run","list","-R",$repo,"--workflow",$workflow,"--limit","3",
                        "--json","databaseId,status,conclusion,createdAt,url")
    } catch {
      if ("$_" -match "404|not found") { Write-Host "   ... esperando a que exista $workflow"; Start-Sleep -Seconds 10; continue }
      throw
    }
    $run = $lista | Where-Object { [datetime]$_.createdAt -ge $desde.AddSeconds(-90) } |
           Sort-Object createdAt -Descending | Select-Object -First 1
    if ($run -and $run.status -eq "completed") { return $run }
    Start-Sleep -Seconds 10
  }
  if ($run) { throw "Timeout esperando $workflow ($($run.url))" }
  throw "Timeout: no aparecio ningun run de $workflow"
}

# ---------------------------------------------------------------- 0. Comprobaciones
Paso "Comprobaciones"
if ($Nombre -cnotmatch '^[a-z0-9][a-z0-9-]{0,14}$') {
  Falla "Nombre invalido: minusculas, digitos y guiones, 15 caracteres maximo (la app de Fly sera '$Nombre-$Owner' y Fly corta a 30)."
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue))  { Falla "Falta gh (winget install GitHub.cli)" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Falla "Falta git" }
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Falla "gh no esta autenticado: gh auth login" }
$flyApp = "$Nombre-$Owner"
$flyctl = Get-Command flyctl -ErrorAction SilentlyContinue
if (-not $flyctl -and (Test-Path "$env:USERPROFILE\.fly\bin\flyctl.exe")) {
  $flyctl = Get-Command "$env:USERPROFILE\.fly\bin\flyctl.exe"
}
$usarDrive = -not $SinDrive -and $DriveWebApp -and $DriveToken
$registro = Join-Path $PSScriptRoot "creados\$Nombre.json"

# ================================================================ MODO ELIMINAR
if ($Eliminar) {
  Paso "ELIMINAR todo rastro de '$Nombre'"
  & gh repo view $repo 2>&1 | Out-Null
  $hayRepo = ($LASTEXITCODE -eq 0)

  # Inventario ANTES de borrar nada: el repo es quien sabe la app de Fly y el
  # id de Drive (variable FLY_APP y tabla Parametros de CLAUDE.md).
  $driveId = ""
  if ($hayRepo) {
    $v = & gh variable get FLY_APP -R $repo 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) { $flyApp = "$v".Trim() }
    $cm = & gh api "repos/$repo/contents/CLAUDE.md" -H "Accept: application/vnd.github.raw" 2>$null
    if ($LASTEXITCODE -eq 0 -and "$cm" -match '(?m)^\| Carpeta de Drive \(id\) \|\s*`?([A-Za-z0-9_-]{10,})`?\s*\|') { $driveId = $Matches[1] }
  }
  if (-not $driveId -and (Test-Path $registro)) {
    try { $driveId = (Get-Content $registro -Raw | ConvertFrom-Json).drive_id } catch {}
  }
  $txtRepo  = 'no existe'; if ($hayRepo) { $txtRepo = "https://github.com/$repo" }
  $txtFly   = $flyApp; if ($SinFly) { $txtFly += ' (omitida por -SinFly)' } elseif (-not $flyctl) { $txtFly += ' (sin flyctl: NO se puede destruir)' }
  $txtDrive = "por nombre '$Nombre' -> papelera"; if ($SinDrive) { $txtDrive = 'omitido por -SinDrive' } elseif ($driveId) { $txtDrive = "id $driveId -> papelera" }
  Write-Host "   Repo GitHub : $txtRepo"
  Write-Host "   App de Fly  : $txtFly"
  Write-Host "   Drive       : $txtDrive"
  Write-Host "   Registro    : $registro"

  if (-not $Forzar) {
    $conf = Read-Host "`n   Escribe el nombre del proyecto para confirmar"
    if ($conf -cne $Nombre) { Falla "Cancelado." }
  }

  # Fly primero: si el repo desaparece antes y no habia flyctl, la app quedaria huerfana y facturando.
  if (-not $SinFly) {
    if ($flyctl) {
      $f = & $flyctl.Source apps destroy $flyApp --yes 2>&1
      if ($LASTEXITCODE -eq 0) { Ok "App de Fly '$flyApp' destruida" }
      elseif ("$f" -match "not find|not found|Could not") { Ok "App de Fly '$flyApp' no existia" }
      else { Falla "flyctl no pudo destruir '$flyApp': $f  (nada mas se ha borrado)" }
    } else { Falla "Sin flyctl no se puede destruir la app de Fly; instala/autentica flyctl o usa -SinFly a sabiendas. Nada se ha borrado." }
  }

  if (-not $SinDrive) {
    if ($DriveWebApp -and $DriveToken) {
      $q = "accion=eliminar&token=$([uri]::EscapeDataString($DriveToken))&nombre=$([uri]::EscapeDataString($Nombre))"
      if ($driveId) { $q += "&id=$([uri]::EscapeDataString($driveId))" }
      try { $d = Invoke-RestMethod -Uri "$DriveWebApp`?$q" -Method Get -MaximumRedirection 5 }
      catch { Aviso "No se pudo llamar al Apps Script: $($_.Exception.Message)" }
      if ($d -and $d.error) { Aviso "Drive: $($d.error)" }
      elseif ($d -and $d.eliminada) { Ok "Carpeta de Drive a la papelera: $($d.url)" }
      elseif ($d) { Ok "Drive: no habia carpeta que borrar" }
    } else { Aviso "Sin DriveWebApp/DriveToken: la carpeta de Drive hay que borrarla a mano" }
  }

  if ($hayRepo) {
    $g = & gh repo delete $repo --yes 2>&1
    if ($LASTEXITCODE -ne 0) {
      if ("$g" -match "delete_repo") { Falla "gh necesita el scope delete_repo:  gh auth refresh -h github.com -s delete_repo   (Fly y Drive ya se han borrado)" }
      Falla "gh repo delete fallo: $g"
    }
    Ok "Repo $repo borrado (con Pages, variables y runs)"
  }

  if (Test-Path $registro) { Remove-Item $registro -Force; Ok "Registro local borrado" }
  Write-Host "`n================ '$Nombre' eliminado ================" -ForegroundColor Green
  exit 0
}

# ================================================================ MODO CREAR
& gh repo view $repo 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Falla "El repo $repo ya existe (usa -Eliminar para borrarlo)." }
Ok "gh autenticado, nombre valido, $repo libre"
if (-not $SinDrive -and -not $usarDrive) { Aviso "Sin DriveWebApp/DriveToken: Drive se omite (fila vacia en CLAUDE.md)" }

# ---------------------------------------------------------------- 1. Repo desde plantilla
Paso "1/6 Crear $repo desde $Plantilla (publico)"
$tCrear = Get-Date
$crearArgs = @("repo","create",$repo,"--template",$Plantilla,"--public")
if ($Descripcion) { $crearArgs += @("--description",$Descripcion) }
& gh @crearArgs | Out-Null
if ($LASTEXITCODE -ne 0) { Falla "gh repo create fallo" }
Ok "https://github.com/$repo"

# ---------------------------------------------------------------- 2. init-plantilla
Paso "2/6 Esperar al workflow 'Inicializar plantilla'"
$run = Wait-Run "init-plantilla.yml" $tCrear $TimeoutMin
if ($run.conclusion -ne "success") { Falla "init-plantilla termino en '$($run.conclusion)': $($run.url)" }
# Doble comprobacion: el marcador tiene que haber desaparecido de main.
& gh api "repos/$repo/contents/.plantilla-pendiente" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Falla "Sigue existiendo .plantilla-pendiente en main" }
Ok "Inicializado ($($run.url))"

# ---------------------------------------------------------------- 3. Pages -> GitHub Actions
Paso "3/6 Pages con origen 'GitHub Actions'"
$r = & gh api -X POST "repos/$repo/pages" -f build_type=workflow 2>&1
if ($LASTEXITCODE -ne 0) {
  # 409: el sitio ya existe (modo rama). Se cambia el origen.
  $r = & gh api -X PUT "repos/$repo/pages" -f build_type=workflow 2>&1
  if ($LASTEXITCODE -ne 0) { Falla "No se pudo configurar Pages: $r" }
}
$tPages = Get-Date
& gh workflow run pages.yml -R $repo --ref main | Out-Null
$run = Wait-Run "pages.yml" $tPages $TimeoutMin
if ($run.conclusion -ne "success") { Falla "pages.yml termino en '$($run.conclusion)': $($run.url)" }
$pagesUrl = "https://$Owner.github.io/$Nombre/"
Ok "$pagesUrl"

# ---------------------------------------------------------------- 4. Drive
$driveId = ""; $driveUrl = ""
if ($usarDrive) {
  Paso "4/6 Carpeta de Drive '$Nombre'"
  $uri = "$DriveWebApp`?nombre=$([uri]::EscapeDataString($Nombre))&token=$([uri]::EscapeDataString($DriveToken))"
  try { $d = Invoke-RestMethod -Uri $uri -Method Get -MaximumRedirection 5 }
  catch { Falla "No se pudo llamar al Apps Script: $($_.Exception.Message)" }
  if (-not $d -or $d.error) { Falla "Apps Script devolvio error: $($d.error)" }
  $driveId = $d.id; $driveUrl = $d.url
  $txtCreada = 'ya existia'; if ($d.creada) { $txtCreada = 'creada' }
  Ok "$driveUrl  (id $driveId, $txtCreada)"
} else { Paso "4/6 Drive: omitido" }

# ---------------------------------------------------------------- 5. Fly
if (-not $SinFly) {
  Paso "5/6 Fly: app '$flyApp' en la org '$FlyOrg'"
  & gh variable set FLY_APP -R $repo -b $flyApp | Out-Null
  if ($LASTEXITCODE -ne 0) { Falla "No se pudo definir la variable FLY_APP" }
  Ok "Variable de repositorio FLY_APP = $flyApp"
  if ($flyctl) {
    $f = & $flyctl.Source apps create $flyApp --org $FlyOrg 2>&1
    if ($LASTEXITCODE -eq 0) { Ok "App creada en Fly" }
    elseif ("$f" -match "already|taken|exists") {
      # Puede ser nuestra (reintento) o ajena. Solo es nuestra si aparece en la org.
      $mias = & $flyctl.Source apps list --org $FlyOrg 2>&1
      if ("$mias" -match "\b$([regex]::Escape($flyApp))\b") { Ok "La app ya existia en la org" }
      else { Falla "El nombre '$flyApp' esta cogido por otra cuenta de Fly. Relanza con otro nombre de proyecto o define FLY_APP a mano." }
    } else { Aviso "flyctl no pudo crear la app ($f); deploy.yml lo intentara" }
  } else { Aviso "flyctl no disponible: deploy.yml creara la app" }
} else { Paso "5/6 Fly: omitido"; $flyApp = "" }

# ---------------------------------------------------------------- 6. CLAUDE.md + deploy
Paso "6/6 Anotar parametros en CLAUDE.md y lanzar el despliegue"
$tmp = Join-Path $env:TEMP "np-$Nombre-$(Get-Random)"
& git clone -q --depth 1 "https://github.com/$repo.git" $tmp
if ($LASTEXITCODE -ne 0) { Falla "git clone fallo" }
$claude = Join-Path $tmp "CLAUDE.md"
$txt = Get-Content $claude -Raw -Encoding UTF8
$valorDrive = ""; if ($driveId) { $valorDrive = '`' + $driveId + '`' }
$txt = [regex]::Replace($txt, '(?m)^(\| Carpeta de Drive \(id\) \|).*$', ('$1 ' + $valorDrive + ' |'))
if ($flyApp) { $txt = [regex]::Replace($txt, '(?m)^(\| App de Fly\.io \|).*$', ('$1 `' + $flyApp + '` |')) }
[IO.File]::WriteAllText($claude, $txt, (New-Object Text.UTF8Encoding $false))
Push-Location $tmp
& git add CLAUDE.md
# Autor del commit: -GitEmail si se pasa, si no el email configurado en git.
$emailCommit = $GitEmail
if (-not $emailCommit) { $emailCommit = (& git config user.email) }
if (-not $emailCommit) { $emailCommit = "nuevo-proyecto@local" }
& git -c user.name="nuevo-proyecto.ps1" -c user.email="$emailCommit" commit -q -m "Anotar parametros: Drive y app de Fly" 2>&1 | Out-Null
$hayCommit = ($LASTEXITCODE -eq 0)
if ($hayCommit) { & git push -q origin HEAD:main; if ($LASTEXITCODE -ne 0) { Pop-Location; Falla "git push fallo" } }
$sha = (& git rev-parse HEAD).Trim()
Pop-Location
Remove-Item -Recurse -Force $tmp
Ok "CLAUDE.md en main ($sha)"

$deployUrl = ""
if (-not $SinFly) {
  $tDeploy = Get-Date
  & gh workflow run deploy.yml -R $repo --ref main | Out-Null
  Write-Host "   ... compilando Rust en Fly (varios minutos)"
  $run = Wait-Run "deploy.yml" $tDeploy ([Math]::Max($TimeoutMin, 20))
  if ($run.conclusion -ne "success") { Aviso "deploy.yml termino en '$($run.conclusion)': $($run.url)  (mira el resumen del run; causa tipica: nombre de app ocupado)" }
  else { $deployUrl = "https://$flyApp.fly.dev/"; Ok "$deployUrl  ($($deployUrl)salud con el SHA)" }
}

# ---------------------------------------------------------------- Resumen
$resumen = [ordered]@{
  proyecto = $Nombre; repo = "https://github.com/$repo"; sha = $sha
  pages = $pagesUrl; bitacora = "${pagesUrl}bitacora.html"
  comprobacion = "${pagesUrl}holamundo.html"
  drive_id = $driveId; drive_url = $driveUrl
  fly_app = $flyApp; fly_url = $deployUrl
  code = "https://claude.ai/code  ->  $repo (main)"
  duracion_min = [Math]::Round(((Get-Date) - $inicio).TotalMinutes, 1)
}
New-Item -ItemType Directory -Force (Split-Path $registro) | Out-Null
$resumen | ConvertTo-Json | Set-Content $registro -Encoding UTF8
Write-Host ""
Write-Host "================ $Nombre listo en $($resumen.duracion_min) min ================" -ForegroundColor Green
$resumen.GetEnumerator() | ForEach-Object { "{0,-13} {1}" -f $_.Key, $_.Value } | Write-Host
Write-Host "`nComprueba a ojo: abre $($resumen.comprobacion) y las dos cajas deben rellenarse."
Write-Host "Siguiente: abre claude.ai/code con $repo seleccionado. No hay nada que pegar."
