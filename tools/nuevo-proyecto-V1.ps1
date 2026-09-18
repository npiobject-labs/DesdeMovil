<#
.SYNOPSIS
  Crea un proyecto nuevo en npiobject-labs: repositorio desde la plantilla,
  Pages, app de Fly.io y clon local, con los parametros anotados en CLAUDE.md.

  Diferencia con la version anterior: la carpeta de Drive y la carpeta local
  las aportas tu. El script NO crea nada en Drive ni depende del Apps Script
  "drive-carpeta.gs", asi que la carpeta puede estar en la cuenta de Google que
  quieras: solo hace falta su id (o su URL).

.EXAMPLE
  .\nuevo-proyecto-V1.ps1 inversion -DriveId 1AbC... -Local "D:\Proyectos\inversion"
  .\nuevo-proyecto-V1.ps1 inversion -DriveId "https://drive.google.com/drive/folders/1AbC..."
  .\nuevo-proyecto-V1.ps1 pruebax -SinFly                  # solo repo + Pages + local
  .\nuevo-proyecto-V1.ps1 pruebax -SinLocal                # sin copia local permanente
  .\nuevo-proyecto-V1.ps1 pruebax -Eliminar                # borra repo, app de Fly y clon local
  .\nuevo-proyecto-V1.ps1 pruebax -Eliminar -Forzar        # sin pedir confirmacion

.NOTES
  Requisitos (una sola vez):
    winget install GitHub.cli ; gh auth login   (scopes: repo, workflow)
    git con credenciales para github.com
    Fly: opcional. Si flyctl esta en el PATH y autenticado, la app se reserva
         aqui, ANTES de crear el repo, para no dejar restos si el nombre esta
         cogido. Si no hay flyctl, la crea deploy.yml.
    Drive: la carpeta la creas tu a mano en la cuenta que quieras y pasas su id
         con -DriveId. Sin -DriveId la fila queda vacia y las sesiones de Code
         omiten el paso de Drive.
    -Eliminar: gh necesita el scope delete_repo (gh auth refresh -s delete_repo);
         flyctl obligatorio para destruir la app. La carpeta de Drive NUNCA se
         toca: el script solo te recuerda cual era.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)][string]$Nombre,
  [string]$Owner        = "npiobject-labs",
  [string]$Plantilla    = "npiobject-labs/DesdeMovil",
  [string]$FlyOrg       = "desdemovil",
  [string]$DriveId      = "",
  [string]$Local        = "",
  [string]$Descripcion  = "",
  [string]$CommitNombre = "",
  [string]$CommitEmail  = "",
  [switch]$SinFly,
  [switch]$SinLocal,
  [switch]$Eliminar,
  [switch]$Forzar,
  [int]$TimeoutMin      = 10
)

# "Continue" a proposito: en Windows PowerShell 5.1, con "Stop", cualquier linea
# que un comando nativo (gh, git, flyctl) escriba en stderr con 2>&1 se convierte
# en error terminal. Los fallos se comprueban con $LASTEXITCODE.
$ErrorActionPreference = "Continue"
$repo    = "$Owner/$Nombre"
$inicio  = Get-Date
$flyApp  = "$Nombre-$Owner"

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
    # El repo recien creado desde plantilla tarda unos segundos en tener
    # contenido: hasta entonces gh responde 404 "workflow not found".
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

# Acepta el id pelado o la URL entera de la carpeta y devuelve solo el id.
function Normaliza-DriveId([string]$v) {
  if (-not $v) { return "" }
  $v = $v.Trim().Trim('"').Trim("'")
  if ($v -match '/folders/([A-Za-z0-9_-]+)') { $v = $Matches[1] }
  elseif ($v -match '[?&]id=([A-Za-z0-9_-]+)') { $v = $Matches[1] }
  if ($v -cnotmatch '^[A-Za-z0-9_-]{15,}$') {
    Falla "El valor de -DriveId no parece un id de carpeta de Drive: '$v'. Abre la carpeta en Drive y copia el tramo que sigue a /folders/."
  }
  return $v
}

# ---------------------------------------------------------------- 0. Comprobaciones
Paso "Comprobaciones"
if ($Nombre -cnotmatch '^[a-z0-9][a-z0-9-]{0,14}$') {
  Falla "Nombre invalido: minusculas, digitos y guiones, 15 caracteres maximo (la app de Fly sera '$flyApp' y Fly corta a 30)."
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue))  { Falla "Falta gh (winget install GitHub.cli)" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Falla "Falta git" }
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Falla "gh no esta autenticado: gh auth login" }

$flyctl = Get-Command flyctl -ErrorAction SilentlyContinue
if (-not $flyctl -and (Test-Path "$env:USERPROFILE\.fly\bin\flyctl.exe")) {
  $flyctl = Get-Command "$env:USERPROFILE\.fly\bin\flyctl.exe"
}
$registro = Join-Path $PSScriptRoot "creados\$Nombre.json"

# ================================================================ MODO ELIMINAR
if ($Eliminar) {
  Paso "ELIMINAR '$Nombre'"
  & gh repo view $repo 2>&1 | Out-Null
  $hayRepo = ($LASTEXITCODE -eq 0)

  # Inventario ANTES de borrar nada: el repo sabe la app de Fly (variable
  # FLY_APP) y el id de Drive (tabla Parametros de CLAUDE.md).
  $driveIdPrev = ""
  $localPrev   = $Local
  if ($hayRepo) {
    $v = & gh variable get FLY_APP -R $repo 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) { $flyApp = "$v".Trim() }
    $cm = & gh api "repos/$repo/contents/CLAUDE.md" -H "Accept: application/vnd.github.raw" 2>$null
    if ($LASTEXITCODE -eq 0 -and "$cm" -match '(?m)^\| Carpeta de Drive \(id\) \|\s*`?([A-Za-z0-9_-]{10,})`?\s*\|') { $driveIdPrev = $Matches[1] }
  }
  if (Test-Path $registro) {
    try {
      $reg = Get-Content $registro -Raw | ConvertFrom-Json
      if (-not $driveIdPrev) { $driveIdPrev = $reg.drive_id }
      if (-not $localPrev)   { $localPrev   = $reg.local }
    } catch {}
  }

  $txtRepo  = 'no existe'; if ($hayRepo) { $txtRepo = "https://github.com/$repo" }
  $txtFly   = $flyApp; if ($SinFly) { $txtFly += ' (omitida por -SinFly)' } elseif (-not $flyctl) { $txtFly += ' (sin flyctl: NO se puede destruir)' }
  $txtLocal = 'ninguna conocida'; if ($localPrev) { $txtLocal = $localPrev }
  if ($SinLocal) { $txtLocal += ' (omitida por -SinLocal)' }
  $txtDrive = 'no habia'; if ($driveIdPrev) { $txtDrive = "https://drive.google.com/drive/folders/$driveIdPrev" }
  Write-Host "   Repo GitHub : $txtRepo"
  Write-Host "   App de Fly  : $txtFly"
  Write-Host "   Carpeta local: $txtLocal"
  Write-Host "   Drive       : $txtDrive  <- NO se toca, borralo tu si quieres"
  Write-Host "   Registro    : $registro"

  if (-not $Forzar) {
    $conf = Read-Host "`n   Escribe el nombre del proyecto para confirmar"
    if ($conf -cne $Nombre) { Falla "Cancelado." }
  }

  # Fly primero: si el repo desaparece antes y no habia flyctl, la app quedaria
  # huerfana y sin quien recuerde su nombre.
  if (-not $SinFly) {
    if ($flyctl) {
      $f = & $flyctl.Source apps destroy $flyApp --yes 2>&1
      if ($LASTEXITCODE -eq 0) { Ok "App de Fly '$flyApp' destruida" }
      elseif ("$f" -match "not find|not found|Could not") { Ok "App de Fly '$flyApp' no existia" }
      else { Falla "flyctl no pudo destruir '$flyApp': $f  (nada mas se ha borrado)" }
    } else { Falla "Sin flyctl no se puede destruir la app de Fly; instala/autentica flyctl o usa -SinFly a sabiendas. Nada se ha borrado." }
  }

  # La copia local solo se borra si de verdad es un clon de ESTE repo.
  if (-not $SinLocal -and $localPrev -and (Test-Path $localPrev)) {
    $origen = & git -C $localPrev remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and "$origen" -match [regex]::Escape("$Owner/$Nombre")) {
      Remove-Item -Recurse -Force $localPrev
      Ok "Carpeta local borrada: $localPrev"
    } else {
      Aviso "'$localPrev' no es un clon de $repo (origin: $origen). No se toca; borrala tu si procede."
    }
  }

  if ($hayRepo) {
    $g = & gh repo delete $repo --yes 2>&1
    if ($LASTEXITCODE -ne 0) {
      if ("$g" -match "delete_repo") { Falla "gh necesita el scope delete_repo:  gh auth refresh -h github.com -s delete_repo   (Fly y el clon local ya se han borrado)" }
      Falla "gh repo delete fallo: $g"
    }
    Ok "Repo $repo borrado (con Pages, variables y runs)"
  }

  if (Test-Path $registro) { Remove-Item $registro -Force; Ok "Registro local borrado" }
  if ($driveIdPrev) { Aviso "Pendiente a mano: la carpeta de Drive $txtDrive" }
  Write-Host "`n================ '$Nombre' eliminado ================" -ForegroundColor Green
  exit 0
}

# ================================================================ MODO CREAR
& gh repo view $repo 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Falla "El repo $repo ya existe (usa -Eliminar para borrarlo)." }

$DriveId = Normaliza-DriveId $DriveId
if (-not $DriveId) { Aviso "Sin -DriveId: la fila de Drive queda vacia y las sesiones omitiran el paso de Drive" }

# La carpeta local se valida AHORA, antes de crear nada en GitHub ni en Fly.
$localTemporal = $false
if ($SinLocal) {
  if ($Local) { Aviso "-SinLocal manda: se ignora -Local y el clon se hace en una carpeta temporal" }
  $Local = Join-Path $env:TEMP "np-$Nombre-$(Get-Random)"
  $localTemporal = $true
} else {
  if (-not $Local) {
    $Local = Join-Path $env:USERPROFILE "C - Desarrollo\$Nombre\repo"
    Aviso "Sin -Local: se usara $Local"
  }
  # GetFullPath resolveria contra el directorio del proceso .NET, que no
  # siempre coincide con el de PowerShell; esto usa el de PowerShell.
  $Local = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Local)
  if (Test-Path $Local) {
    if (@(Get-ChildItem -Force $Local -ErrorAction SilentlyContinue).Count -gt 0) {
      Falla "La carpeta local '$Local' ya existe y no esta vacia. Elige otra con -Local o vaciala."
    }
  } else {
    $padre = Split-Path $Local -Parent
    if ($padre -and -not (Test-Path $padre)) {
      New-Item -ItemType Directory -Force $padre | Out-Null
    }
  }
}

# Identidad para el commit de parametros: la del PC si la hay, si no la de gh.
if (-not $CommitNombre) { $CommitNombre = (& git config --global user.name  2>$null) }
if (-not $CommitEmail)  { $CommitEmail  = (& git config --global user.email 2>$null) }
if (-not $CommitNombre) { $CommitNombre = "nuevo-proyecto-V1" }
if (-not $CommitEmail) {
  $login = & gh api user -q .login 2>$null
  if ($LASTEXITCODE -eq 0 -and $login) { $CommitEmail = "$("$login".Trim())@users.noreply.github.com" }
  else { $CommitEmail = "nuevo-proyecto-v1@users.noreply.github.com" }
}
Ok "gh autenticado, nombre valido, $repo libre, destino local $Local"

# ---------------------------------------------------------------- 1. Fly (reserva)
# Se reserva el nombre ANTES de crear el repo: si esta cogido por otra cuenta,
# no dejamos un repo a medias que luego hay que borrar.
if (-not $SinFly) {
  Paso "1/6 Fly: reservar la app '$flyApp' en la org '$FlyOrg'"
  if ($flyctl) {
    $f = & $flyctl.Source apps create $flyApp --org $FlyOrg 2>&1
    if ($LASTEXITCODE -eq 0) { Ok "App creada en Fly" }
    elseif ("$f" -match "already|taken|exists") {
      # Puede ser nuestra (reintento) o ajena. Solo es nuestra si sale en la org.
      $mias = & $flyctl.Source apps list --org $FlyOrg 2>&1
      if ("$mias" -match "\b$([regex]::Escape($flyApp))\b") { Ok "La app ya existia en la org" }
      else { Falla "El nombre '$flyApp' esta cogido por otra cuenta de Fly. Usa otro nombre de proyecto. No se ha creado nada." }
    } else { Aviso "flyctl no pudo crear la app ($f); deploy.yml lo intentara" }
  } else { Aviso "flyctl no disponible: deploy.yml creara la app" }
} else { Paso "1/6 Fly: omitido"; $flyApp = "" }

# ---------------------------------------------------------------- 2. Repo desde plantilla
Paso "2/6 Crear $repo desde $Plantilla (publico)"
$tCrear = Get-Date
$crearArgs = @("repo","create",$repo,"--template",$Plantilla,"--public")
if ($Descripcion) { $crearArgs += @("--description",$Descripcion) }
& gh @crearArgs | Out-Null
if ($LASTEXITCODE -ne 0) { Falla "gh repo create fallo" }
Ok "https://github.com/$repo"

# ---------------------------------------------------------------- 3. init-plantilla
Paso "3/6 Esperar al workflow 'Inicializar plantilla'"
$run = Wait-Run "init-plantilla.yml" $tCrear $TimeoutMin
if ($run.conclusion -ne "success") { Falla "init-plantilla termino en '$($run.conclusion)': $($run.url)" }
# Doble comprobacion: el marcador tiene que haber desaparecido de main.
& gh api "repos/$repo/contents/.plantilla-pendiente" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Falla "Sigue existiendo .plantilla-pendiente en main" }
Ok "Inicializado ($($run.url))"

# ---------------------------------------------------------------- 4. Pages
Paso "4/6 Pages con origen 'GitHub Actions'"
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

# ---------------------------------------------------------------- 5. Variable FLY_APP
if (-not $SinFly) {
  Paso "5/6 Variable de repositorio FLY_APP"
  & gh variable set FLY_APP -R $repo -b $flyApp | Out-Null
  if ($LASTEXITCODE -ne 0) { Falla "No se pudo definir la variable FLY_APP" }
  Ok "FLY_APP = $flyApp"
} else { Paso "5/6 Fly: omitido" }

# ---------------------------------------------------------------- 6. Clon local + CLAUDE.md
Paso "6/6 Clonar en '$Local', anotar CLAUDE.md y lanzar el despliegue"
& git clone -q "https://github.com/$repo.git" $Local
if ($LASTEXITCODE -ne 0) { Falla "git clone fallo sobre '$Local'" }

$claude = Join-Path $Local "CLAUDE.md"
if (-not (Test-Path $claude)) { Falla "El clon no tiene CLAUDE.md: algo fue mal en la plantilla" }
$txt = Get-Content $claude -Raw -Encoding UTF8
$valorDrive = ""; if ($DriveId) { $valorDrive = '`' + $DriveId + '`' }
$txt = [regex]::Replace($txt, '(?m)^(\| Carpeta de Drive \(id\) \|).*$', ('$1 ' + $valorDrive + ' |'))
if ($flyApp) { $txt = [regex]::Replace($txt, '(?m)^(\| App de Fly\.io \|).*$', ('$1 `' + $flyApp + '` |')) }
[IO.File]::WriteAllText($claude, $txt, (New-Object Text.UTF8Encoding $false))

Push-Location $Local
& git add CLAUDE.md
& git -c user.name="$CommitNombre" -c user.email="$CommitEmail" commit -q -m "Anotar parametros: Drive y app de Fly" 2>&1 | Out-Null
$hayCommit = ($LASTEXITCODE -eq 0)
if ($hayCommit) {
  # Por si algun workflow commiteo a main mientras tanto.
  & git pull -q --rebase origin main 2>&1 | Out-Null
  & git push -q -u origin HEAD:main
  if ($LASTEXITCODE -ne 0) { Pop-Location; Falla "git push fallo desde '$Local'" }
}
$sha = (& git rev-parse HEAD).Trim()
Pop-Location
if ($localTemporal) { Remove-Item -Recurse -Force $Local; $Local = "" }
Ok "CLAUDE.md en main ($sha)"

$deployUrl = ""
if (-not $SinFly) {
  $tDeploy = Get-Date
  & gh workflow run deploy.yml -R $repo --ref main | Out-Null
  Write-Host "   ... compilando Rust en Fly (varios minutos)"
  $run = Wait-Run "deploy.yml" $tDeploy ([Math]::Max($TimeoutMin, 20))
  if ($run.conclusion -ne "success") { Aviso "deploy.yml termino en '$($run.conclusion)': $($run.url)  (mira el resumen del run)" }
  else { $deployUrl = "https://$flyApp.fly.dev/"; Ok "$deployUrl  ($($deployUrl)salud con el SHA)" }
}

# ---------------------------------------------------------------- Resumen
$driveUrl = ""; if ($DriveId) { $driveUrl = "https://drive.google.com/drive/folders/$DriveId" }
$resumen = [ordered]@{
  proyecto = $Nombre; repo = "https://github.com/$repo"; sha = $sha
  pages = $pagesUrl; bitacora = "${pagesUrl}bitacora.html"
  comprobacion = "${pagesUrl}holamundo.html"
  local = $Local
  drive_id = $DriveId; drive_url = $driveUrl
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
