<#
.SYNOPSIS
  Peripateticos: ELIMINAR o RENOMBRAR una app montada con peripateticos.ps1,
  desde el PC con Windows, que es quien tiene las llaves de GitHub y Fly.io.

  -Accion eliminar  : borra el servidor de Fly.io y el repositorio de GitHub
                      (con su web y su bitacora). No se puede deshacer.
  -Accion renombrar : cambia el nombre del repositorio (y con el, la web),
                      crea el servidor con el nombre nuevo y borra el viejo
                      (Fly.io no deja renombrar apps), anota el nombre nuevo en
                      el servidor, CLAUDE.md y nacimiento.json, y renombra la
                      copia del PC.

  Lo que este script NO toca:
    - Google Drive: el PC no puede entrar. Lo hace antes (eliminar) o despues
      (renombrar) una sesion de Claude con el conector de Google Drive, guiada
      desde desinstalar.html / renombrar.html; si no puede, el usuario a mano.
    - Al eliminar, la copia del PC (Documentos\Peripateticos\<app>): es del
      usuario, que decide si la guarda o la borra.
    - Las cuentas, la organizacion, su llave de Fly.io y los ayudantes: sirven
      para las demas apps.

  Normalmente lo lanza el .cmd que genera docs/pc.html?accion=..., que fija
  PERI_ACCION, PERI_APP, PERI_ORG, PERI_NUEVO (al renombrar) y PERI_PLANTILLA.

.EXAMPLE
  .\mantenimiento.ps1 -Accion eliminar  -App recetas -Org apps-de-maria -Simular
  .\mantenimiento.ps1 -Accion eliminar  -App recetas -Org apps-de-maria
  .\mantenimiento.ps1 -Accion renombrar -App recetas -Org apps-de-maria -Nuevo cocina

.NOTES
  Mismas reglas que peripateticos.ps1: Windows PowerShell 5.1, solo ASCII,
  sin "exit" y reanudable (volver a abrir el mismo .cmd sigue donde iba).
  Antes de tocar nada ensena el plan y pide confirmacion escrita.

  Al eliminar, Fly.io va primero y GitHub el ultimo: mientras el repositorio
  existe es quien sabe como se llama el servidor y cual es la carpeta de Drive.

  Solo para pruebas: PERI_CONFIRMAR (la respuesta, sin preguntar),
  PERI_INTERVALO, PERI_SIN_NAVEGADOR, PERI_URL_ZIP, PERI_DOCS (la carpeta de
  Documentos) y PERI_URL_WEB / PERI_URL_SERVIDOR (sustituyen la web y el
  servidor nuevos al comprobar).
#>
[CmdletBinding()]
param(
  [string]$Accion    = $env:PERI_ACCION,
  [string]$App       = $env:PERI_APP,
  [string]$Org       = $env:PERI_ORG,
  [string]$Nuevo     = $env:PERI_NUEVO,
  [string]$Plantilla = $(if ($env:PERI_PLANTILLA) { $env:PERI_PLANTILLA } else { "npiobject-labs/DesdeMovil" }),
  [string]$Bin       = $env:PERI_BIN,
  [int]$TimeoutMin   = 20,
  [switch]$Simular
)

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$script:inicio    = Get-Date
$script:intervalo = 10
if ($env:PERI_INTERVALO) { $script:intervalo = [int]$env:PERI_INTERVALO }
$script:ayuda     = @()
$script:hecho     = [ordered]@{}

# ---------------------------------------------------------------- Salida por pantalla
function Paso([string]$t)  { $script:tPaso = Get-Date; Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Seg() { if (-not $script:tPaso) { return "" }; return " ({0})" -f (Tiempo $script:tPaso) }
function Tiempo([datetime]$desde) {
  $s = [int]((Get-Date) - $desde).TotalSeconds
  if ($s -lt 60) { return "${s}s" }
  return "{0}m {1:00}s" -f [Math]::Floor($s / 60), ($s % 60)
}
function Ok([string]$t)    { Write-Host "   OK  $t$(Seg)" -ForegroundColor Green }
function Aviso([string]$t) { Write-Host "   !!  $t" -ForegroundColor Yellow }
function Nota([string]$t)  { Write-Host "   ..  $t" -ForegroundColor DarkGray }
function Dice([string]$t)  { Write-Host "   $t" }
function Fuerte([string]$t){ Write-Host "   $t" -ForegroundColor White }
function Rojo([string]$t)  { Write-Host "   $t" -ForegroundColor Red }
function Falla([string]$t, [string[]]$ayuda = @()) { $script:ayuda = $ayuda; throw $t }
function Abrir([string]$url) {
  if ($env:PERI_SIN_NAVEGADOR) { Nota "(se abriria $url)"; return }
  try { Start-Process $url } catch { Aviso "Abre tu navegador en: $url" }
}
function Copiar([string]$t) { try { Set-Clipboard -Value $t -ErrorAction Stop } catch { } }

# ---------------------------------------------------------------- Nombres (las reglas del instalador)
function Slug([string]$v) {
  $x = "$v".Trim().ToLowerInvariant()
  $x = $x -replace '[\s_.]+', '-'
  $x = $x -replace '[^a-z0-9-]', ''
  $x = $x -replace '-{2,}', '-'
  $x = $x.Trim('-')
  if ($x.Length -gt 15) {
    $x = $x.Substring(0, 15)
    if ($x.IndexOf('-') -gt 0) { $x = $x -replace '-[^-]*$', '' }
  }
  return $x.TrimEnd('-')
}
function NombreFly([string]$v) {
  $x = "$v".ToLowerInvariant() -replace '[^a-z0-9-]', '-'
  if ($x.Length -gt 30) { $x = $x.Substring(0, 30) }
  return $x.TrimEnd('-')
}

# ---------------------------------------------------------------- Comandos nativos
function Nativo([string]$exe, [string[]]$a, [switch]$SoloSalida) {
  if ($SoloSalida) { $salida = & $exe @a 2>$null } else { $salida = & $exe @a 2>&1 }
  $codigo = $LASTEXITCODE
  $txt = (@($salida) | ForEach-Object { "$_" }) -join "`n"
  return [pscustomobject]@{ ok = ($codigo -eq 0); codigo = $codigo; texto = $txt.Trim() }
}
function Gh([string[]]$a, [switch]$SoloSalida)  { return Nativo $script:gh  $a -SoloSalida:$SoloSalida }
function Fly([string[]]$a, [switch]$SoloSalida) { return Nativo $script:fly $a -SoloSalida:$SoloSalida }

function Esperar([string]$que, [scriptblock]$listo, [double]$minutos) {
  $t0 = Get-Date
  $limite = $t0.AddMinutes($minutos)
  $ultimaNota = $t0
  while ((Get-Date) -lt $limite) {
    $r = & $listo
    if ($r) { return $r }
    if (((Get-Date) - $ultimaNota).TotalSeconds -ge 30) { $ultimaNota = Get-Date; Nota ("{0}: {1}" -f $que, (Tiempo $t0)) }
    Start-Sleep -Seconds $script:intervalo
  }
  return $null
}

# ---------------------------------------------------------------- Ayudantes (gh y flyctl)
function Buscar-Exe([string[]]$nombres, [string[]]$rutas) {
  foreach ($n in $nombres) {
    $c = Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Path }
  }
  foreach ($r in $rutas) { if ($r -and (Test-Path $r)) { return $r } }
  return $null
}
function Instalar-Ayudante([string]$repo, [string]$patron, [string]$exe, [string]$reserva) {
  $url = $null
  try {
    $rel = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "peripateticos" } -TimeoutSec 30
    $asset = @($rel.assets | Where-Object { $_.name -match $patron }) | Select-Object -First 1
    if ($asset) { $url = $asset.browser_download_url }
  } catch { }
  if (-not $url) { $url = $reserva; Nota "usando la version conocida de $exe" }
  $tmp = [IO.Path]::GetTempPath()
  $zip = Join-Path $tmp "peri-$exe.zip"
  $dir = Join-Path $tmp "peri-$exe"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip -TimeoutSec 600
  if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
  Expand-Archive -Path $zip -DestinationPath $dir -Force
  Get-ChildItem -Path $dir -Recurse -Include "$exe.exe", "*.dll" | Copy-Item -Destination $Bin -Force
  Remove-Item -Force $zip -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
  $destino = Join-Path $Bin "$exe.exe"
  if (-not (Test-Path $destino)) { Falla "No se pudo instalar $exe." @("Comprueba que el PC tiene internet y vuelve a abrir el archivo.") }
  return $destino
}
function Ayudantes {
  if (-not (Test-Path $Bin)) { New-Item -ItemType Directory -Force $Bin | Out-Null }
  $arm = ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64")
  $script:gh = Buscar-Exe @("gh") @((Join-Path $Bin "gh.exe"), "$env:ProgramFiles\GitHub CLI\gh.exe")
  if ($script:gh) { Ok "Ayudante de GitHub: ya estaba" }
  else {
    $p = '_windows_amd64\.zip$'; if ($arm) { $p = '_windows_arm64\.zip$' }
    $script:gh = Instalar-Ayudante "cli/cli" $p "gh" "https://github.com/cli/cli/releases/download/v2.60.0/gh_2.60.0_windows_amd64.zip"
    Ok "Ayudante de GitHub instalado"
  }
  $script:fly = Buscar-Exe @("flyctl", "fly") @((Join-Path $Bin "flyctl.exe"), "$env:USERPROFILE\.fly\bin\flyctl.exe")
  if ($script:fly) { Ok "Ayudante de Fly.io: ya estaba" }
  else {
    $p = '_Windows_x86_64\.zip$'; if ($arm) { $p = '_Windows_arm64\.zip$' }
    $script:fly = Instalar-Ayudante "superfly/flyctl" $p "flyctl" "https://github.com/superfly/flyctl/releases/download/v0.3.40/flyctl_0.3.40_Windows_x86_64.zip"
    Ok "Ayudante de Fly.io instalado"
  }
}

# ---------------------------------------------------------------- Entrar en GitHub y en Fly.io
# Con la entrada y la salida redirigidas, gh no espera a Intro ni abre el
# navegador: el codigo se lee de su salida y el navegador lo abre este script.
function Autorizar([string[]]$orden) {
  Dice "Se va a abrir tu navegador en GitHub."
  Dice "Cuando te pida un codigo, escribe el que sale aqui abajo"
  Dice "(tambien lo tienes copiado: puedes pegarlo)."
  $script:codigoVisto = $false
  $script:lineasLogin = @()
  "" | & $script:gh @orden 2>&1 | ForEach-Object {
    $l = "$_"
    $script:lineasLogin += $l
    if (-not $script:codigoVisto -and $l -match '\b([A-Z0-9]{4}-[A-Z0-9]{4})\b') {
      $script:codigoVisto = $true
      Write-Host ""
      Write-Host ("            " + $Matches[1] + "            ") -ForegroundColor Black -BackgroundColor Yellow
      Write-Host ""
      Copiar $Matches[1]
      Abrir "https://github.com/login/device"
      Nota "Esperando a que lo autorices en el navegador (tienes 15 minutos)"
    }
  }
  if ($LASTEXITCODE -ne 0) {
    $detalle = @($script:lineasLogin | Where-Object { $_ -and $_ -notmatch 'one-time code|Open this URL' } | Select-Object -Last 2)
    Falla "No se completo la entrada en GitHub." (@("Vuelve a abrir el archivo y, en GitHub, pulsa 'Authorize'.") + $detalle)
  }
}
# Entra (o amplia permisos) hasta tener $necesarios. Si hay que entrar de cero
# pide tambien los del instalador, para que el PC siga sirviendo para montar apps.
function Entrar-GitHub([string[]]$necesarios) {
  $estado = Gh @("auth", "status", "--hostname", "github.com")
  if (-not $estado.ok) {
    $todos = @(@("repo", "workflow", "admin:org") + $necesarios | Select-Object -Unique)
    Autorizar @("auth", "login", "--hostname", "github.com", "--git-protocol", "https", "--web", "--scopes", ($todos -join ","))
  } else {
    $sc = ""; if ($estado.texto -match "Token scopes:\s*(.*)") { $sc = $Matches[1] }
    $faltan = @($necesarios | Where-Object { $sc -notmatch ("(^|[\s',])" + [regex]::Escape($_) + "([\s',]|$)") })
    if ($faltan.Count -gt 0) {
      if ($faltan -contains "delete_repo") { Dice "GitHub te va a pedir un permiso nuevo: 'delete_repo', borrar repositorios. Solo se usa para esto." }
      Autorizar @("auth", "refresh", "--hostname", "github.com", "--scopes", ($faltan -join ","))
    }
  }
  $script:login = (Gh @("api", "user", "-q", ".login") -SoloSalida).texto
  if (-not $script:login) { Falla "GitHub no responde con tu usuario." @("Vuelve a abrir el archivo.") }
  Ok "Hola, $($script:login)"
}
function Entrar-Fly {
  $w = Fly @("auth", "whoami") -SoloSalida
  if (-not $w.ok) {
    Dice "Se abre el navegador otra vez, ahora en Fly.io. Pulsa 'Authorize'."
    & $script:fly auth login
    $w = Fly @("auth", "whoami") -SoloSalida
    if (-not $w.ok) { Falla "No se completo la entrada en Fly.io." @("Vuelve a abrir el archivo y, en Fly.io, pulsa 'Authorize'.") }
  }
  Ok ("Cuenta de Fly.io: " + (($w.texto -split "`n") | Select-Object -Last 1).Trim())
}
# $true, $false o $null (no se sabe).
function Fly-Existe([string]$nombre) {
  $l = Fly @("apps", "list", "--json") -SoloSalida
  if (-not $l.ok) { return $null }
  return ($l.texto -match ('"' + [regex]::Escape($nombre) + '"'))
}
function Fly-Destruir([string]$nombre) {
  $d = Fly @("apps", "destroy", $nombre, "--yes")
  if ($d.ok) { return "borrada" }
  if ($d.texto -match "(?i)not found|could not find|no such app|unknown app") { return "no existia" }
  Falla "Fly.io no deja borrar el servidor '$nombre': $($d.texto)" @("Vuelve a abrir el archivo. Si se repite, haz una foto y pegasela a Claude.")
}

# ---------------------------------------------------------------- GitHub: repositorio, ficheros, runs
# El repositorio tal como lo ve la API. Ojo: si se renombro, GitHub redirige el
# nombre viejo al nuevo, y .name trae el nuevo.
function Leer-Repo([string]$ruta) {
  $r = Gh @("api", "repos/$ruta", "--jq", '[.id, .name, .full_name, .is_template, .permissions.admin] | @tsv') -SoloSalida
  if (-not $r.ok -or -not $r.texto) { return $null }
  $c = $r.texto.Trim() -split "`t"
  return [pscustomobject]@{ id = $c[0]; name = $c[1]; full = $c[2]; plantilla = ($c[3] -eq "true"); admin = ($c[4] -eq "true") }
}
function Leer-Fichero([string]$ruta) {
  $r = Gh @("api", "repos/$($script:repo)/contents/$ruta", "--jq", '[.sha, .content] | @tsv') -SoloSalida
  if (-not $r.ok -or -not $r.texto) { return $null }
  $p = $r.texto -split "`t", 2
  $b64 = $p[1] -replace '\\n', ''
  return [pscustomobject]@{ sha = $p[0]; texto = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) }
}
# Devuelve el SHA del commit, o $null si no se pudo.
function Escribir-Fichero([string]$ruta, [string]$texto, [string]$sha, [string]$mensaje) {
  $cuerpo = [ordered]@{ message = $mensaje; content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($texto)) }
  if ($sha) { $cuerpo.sha = $sha }
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("peri-" + [guid]::NewGuid().ToString("N") + ".json")
  [IO.File]::WriteAllText($tmp, ($cuerpo | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
  $r = Gh @("api", "-X", "PUT", "repos/$($script:repo)/contents/$ruta", "--input", $tmp, "--jq", ".commit.sha") -SoloSalida
  Remove-Item -Force $tmp -ErrorAction SilentlyContinue
  if ($r.ok -and $r.texto) { return $r.texto.Trim() }
  return $null
}
function Leer-Json([string]$ruta) {
  $f = Leer-Fichero $ruta
  if (-not $f) { return $null }
  try { return ($f.texto | ConvertFrom-Json) } catch { return $null }
}
function Runs([string]$wf) {
  $jq = '.[] | [.databaseId, .status, (.conclusion // ""), .headSha, .url] | @tsv'
  $r = Gh @("run", "list", "-R", $script:repo, "--workflow", $wf, "--limit", "20",
            "--json", "databaseId,status,conclusion,headSha,url", "--jq", $jq) -SoloSalida
  $lista = @()
  if (-not $r.ok -or -not $r.texto) { return $lista }
  foreach ($l in ($r.texto -split "`n")) {
    $c = $l.Trim() -split "`t"
    if ($c.Count -ge 5) { $lista += [pscustomobject]@{ id = $c[0]; status = $c[1]; conclusion = $c[2]; sha = $c[3]; url = $c[4] } }
  }
  return $lista
}
# Espera al run de $wf para el commit $sha. Si no aparece en 2 minutos, lo lanza.
function Esperar-Run([string]$wf, [string]$sha, [string]$etiqueta, [double]$minutos) {
  $wfL = $wf; $shaL = $sha
  $run = Esperar $etiqueta { Runs $wfL | Where-Object { $_.sha -eq $shaL } | Select-Object -First 1 } 2
  if (-not $run) {
    $l = Gh @("workflow", "run", $wf, "-R", $script:repo, "--ref", "main")
    if (-not $l.ok) { Falla "No se pudo lanzar $wf : $($l.texto)" @("Vuelve a abrir el archivo.") }
    $run = Esperar $etiqueta { Runs $wfL | Where-Object { $_.sha -eq $shaL } | Select-Object -First 1 } 2
    if (-not $run) { Falla "GitHub no arranca $wf." @("Vuelve a abrir el archivo dentro de unos minutos.") }
  }
  $id = $run.id
  $fin = Esperar $etiqueta { Runs $wfL | Where-Object { $_.id -eq $id -and $_.status -eq "completed" } | Select-Object -First 1 } $minutos
  if (-not $fin) { Falla "$etiqueta lleva mas de $minutos minutos." @("Mira lo que pasa aqui: $($run.url)", "Vuelve a abrir el archivo: sigue donde lo dejo.") }
  if ($fin.conclusion -ne "success") { Falla "$etiqueta ha fallado." @("Detalle: $($fin.url)", "Haz una foto de esa pagina y pegasela a Claude, o vuelve a abrir el archivo.") }
  return $fin
}
function Http([string]$url) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30 -Headers @{ "Cache-Control" = "no-cache" }
    $txt = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    return [pscustomobject]@{ codigo = [int]$r.StatusCode; texto = $txt }
  } catch { return $null }
}
function Hola([string]$servidor) {
  $h = Http ($servidor + "hola")
  if (-not $h -or $h.codigo -ne 200) { return $null }
  try { return ($h.texto | ConvertFrom-Json) } catch { return $null }
}

# ---------------------------------------------------------------- Copia en el PC
function Carpeta-Copias {
  $docs = $env:PERI_DOCS
  if (-not $docs) { $docs = [Environment]::GetFolderPath("MyDocuments") }
  if (-not $docs) { $docs = $HOME }
  return (Join-Path $docs "Peripateticos")
}
function Escritorio {
  if ($env:PERI_ESCRITORIO) { return $env:PERI_ESCRITORIO }
  return [Environment]::GetFolderPath("Desktop")
}
function Bajar-Repo([string]$url, [string]$destino) {
  $tmp = [IO.Path]::GetTempPath()
  $zip = Join-Path $tmp "peri-copia.zip"
  $dir = Join-Path $tmp "peri-copia"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip -TimeoutSec 300
  if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
  Expand-Archive -Path $zip -DestinationPath $dir -Force
  $raiz = Get-ChildItem -Path $dir | Select-Object -First 1
  if (-not $raiz) { throw "el zip del repositorio viene vacio" }
  if (Test-Path $destino) { Remove-Item -Recurse -Force $destino }
  Move-Item -Path $raiz.FullName -Destination $destino
  Remove-Item -Force $zip -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
}
function Acceso([string]$carpeta, [string]$nombre, [string]$url) {
  [IO.File]::WriteAllLines((Join-Path $carpeta "$nombre.url"), [string[]]@("[InternetShortcut]", "URL=$url"))
}
# Lo mismo que deja el instalador en su paso 7, con los datos de ahora.
function Preparar-Copia([string]$carpeta, [string]$app, [string]$repo, [string]$web, [string]$servidor, [string]$driveId) {
  $lineas = @(("Web         " + $web), ("Servidor    " + $servidor), ("Saludo      " + $servidor + "hola"),
              ("Donde vive  https://github.com/" + $repo), ("Bitacora    " + $web + "bitacora.html"))
  if ($driveId) { $lineas += ("Drive       https://drive.google.com/drive/folders/" + $driveId) }
  $zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
  $urlZip = $zipUrl; if ($env:PERI_URL_ZIP) { $urlZip = $env:PERI_URL_ZIP }
  $destinoRepo = Join-Path $carpeta "repo"
  $copia = Esperar "Bajando la copia" { try { Bajar-Repo $urlZip $destinoRepo; "ok" } catch { $script:errCopia = $_.Exception.Message; $null } } 1
  if ($copia) { Ok "Copia del repositorio al dia en $destinoRepo" }
  else { Aviso "No se pudo bajar la copia ($($script:errCopia)). Luego: doble clic en 'Actualizar copia.cmd'." }
  $txt = @("Tu app $app", ("=" * 60), "") + $lineas + @("", "Para cambiarla: Claude en el movil -> Code -> $repo.")
  [IO.File]::WriteAllLines((Join-Path $carpeta "$app.txt"), [string[]]$txt)
  Acceso $carpeta "Web de $app" $web
  Acceso $carpeta "Servidor de $app" ($servidor + "hola")
  Acceso $carpeta "Bitacora de $app" ($web + "bitacora.html")
  Acceso $carpeta "Codigo en GitHub" ("https://github.com/" + $repo)
  Acceso $carpeta "Claude Code" "https://claude.ai/code"
  if ($driveId) { Acceso $carpeta "Carpeta de Drive" ("https://drive.google.com/drive/folders/" + $driveId) }
  [IO.File]::WriteAllLines((Join-Path $carpeta "LEEME.txt"), [string[]]@(
    "Copia de seguridad de $app", ("=" * 60), "",
    "Esta carpeta es una COPIA de tu app. No edites nada aqui: tu app se",
    "cambia desde el movil, pidiendoselo a Claude. Lo que cambies aqui se",
    "pierde la proxima vez que actualices la copia.", "",
    "repo\                    todo el repositorio: CLAUDE.md, documentacion,",
    "                         paginas (docs\) y servidor (app\).",
    "$app.txt                 la ficha: donde vive cada cosa.",
    "Actualizar copia.cmd     doble clic: trae la ultima version de GitHub.",
    "*.url                    accesos directos a la web, el servidor, la",
    "                         bitacora, el codigo, Claude y tu Drive."))
  $ps = "try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; " +
        "`$ProgressPreference = 'SilentlyContinue'; `$d = `$env:PERI_DIR.TrimEnd('\'); `$z = Join-Path `$env:TEMP 'peri-copia.zip'; `$t = Join-Path `$env:TEMP 'peri-copia'; " +
        "Write-Host 'Bajando la ultima version de $repo...'; Invoke-WebRequest -UseBasicParsing -Uri `$env:PERI_ZIP -OutFile `$z; " +
        "if (Test-Path `$t) { Remove-Item -Recurse -Force `$t }; Expand-Archive -Path `$z -DestinationPath `$t -Force; " +
        "`$r = Join-Path `$d 'repo'; if (Test-Path `$r) { Remove-Item -Recurse -Force `$r }; " +
        "Move-Item -Path (Get-ChildItem `$t | Select-Object -First 1).FullName -Destination `$r; Remove-Item -Force `$z; " +
        "Write-Host 'Copia actualizada.' -ForegroundColor Green } catch { Write-Host ('No se pudo actualizar: ' + `$_.Exception.Message) -ForegroundColor Red }"
  $cmd = @("@echo off", "title Actualizar la copia de $app", "setlocal", 'set "PERI_DIR=%~dp0"',
    ('set "PERI_ZIP=' + $zipUrl + '"'),
    ('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "' + $ps + '"'),
    "echo.", "echo Pulsa una tecla para cerrar esta ventana.", "pause >nul")
  [IO.File]::WriteAllText((Join-Path $carpeta "Actualizar copia.cmd"), (($cmd -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding))
  Ok "Ficha, accesos directos y 'Actualizar copia.cmd' con el nombre nuevo"
}

# ---------------------------------------------------------------- Confirmacion escrita
# Devuelve $true si escribe exactamente $esperado (tres intentos).
function Confirmar([string]$pregunta, [string]$esperado) {
  for ($i = 3; $i -ge 1; $i--) {
    if ($env:PERI_CONFIRMAR -ne $null -and $env:PERI_CONFIRMAR -ne "") { $r = $env:PERI_CONFIRMAR; Nota "(respuesta de prueba: $r)" }
    else { $r = Read-Host "   $pregunta" }
    if ("$r".Trim() -ceq $esperado) { return $true }
    if ($env:PERI_CONFIRMAR) { break }
    if ($i -gt 1) { Aviso "No coincide. Te quedan $($i - 1) intentos." }
  }
  return $false
}

# ---------------------------------------------------------------- Comun a las dos acciones
function Encabezado([string]$titulo, [string]$linea, [ConsoleColor]$fondo) {
  Write-Host ""
  Write-Host ("  " + ("=" * 58)) -ForegroundColor White -BackgroundColor $fondo
  Write-Host ("  {0,-58}" -f ("  " + $titulo)) -ForegroundColor White -BackgroundColor $fondo
  Write-Host ("  {0,-58}" -f ("  " + $linea)) -ForegroundColor White -BackgroundColor $fondo
  Write-Host ("  " + ("=" * 58)) -ForegroundColor White -BackgroundColor $fondo
  Write-Host ""
}
function Comprobar-Repo($r, [string]$nombre) {
  if (-not $r.admin) {
    Falla "Tu usuario '$($script:login)' no puede administrar $($r.full)." @("Entra en GitHub con la cuenta que monto la app y vuelve a abrir el archivo.")
  }
  if ($r.plantilla -or $r.full -ieq $Plantilla) {
    Falla "$($r.full) es el molde del que nacen las apps: no se toca desde aqui." @("Si de verdad quieres borrarlo, hazlo a mano en GitHub.")
  }
}
function Id-Drive([string]$texto) {
  if ("$texto" -match '(?m)^\| Carpeta de Drive \(id\) \|\s*`?([A-Za-z0-9_-]{25,})`?\s*\|') { return $Matches[1] }
  return ""
}

# ================================================================ Eliminar
function Eliminar {
  $App = $script:App; $Org = $script:Org
  $script:repo = "$Org/$App"
  Encabezado ("PELIGRO :: eliminar la app `"$App`"") "Borra tu app de internet. No se puede deshacer." DarkRed
  Fuerte "Antes de borrar nada te ensenare lo que voy a hacer y te pedire"
  Fuerte "que escribas el nombre de tu app. Si no lo escribes, no pasa nada."

  Paso "1/6 Ayudantes"
  Ayudantes
  Paso "2/6 Entrar en GitHub"
  Entrar-GitHub @("repo", "delete_repo")
  Paso "3/6 Entrar en Fly.io"
  Entrar-Fly

  # ------------------------------------------------------------ 4/6 Que hay
  Paso "4/6 Lo que hay de '$App'"
  $r = Leer-Repo $script:repo
  if ($r -and $r.name -ine $App) {
    Falla "La app '$App' ahora se llama '$($r.name)': GitHub redirige el nombre viejo." @("Vuelve al movil y elige '$($r.name)' para eliminarla.")
  }
  $flyApp = NombreFly "$App-$Org"
  $driveId = ""; $baja = $null; $nac = $null
  if ($r) {
    Comprobar-Repo $r $App
    $v = Gh @("variable", "get", "FLY_APP", "-R", $script:repo) -SoloSalida
    if ($v.ok -and $v.texto) { $flyApp = $v.texto.Trim() }
    $cm = Leer-Fichero "CLAUDE.md"
    if ($cm) { $driveId = Id-Drive $cm.texto }
    $baja = Leer-Json "docs/baja.json"
    $nac = Leer-Json "docs/nacimiento.json"
    Ok "Repositorio: https://github.com/$($script:repo)"
  } else { Nota "No hay repositorio $($script:repo) en GitHub (ya borrado, o nunca existio)" }
  $enFly = Fly-Existe $flyApp
  if ($enFly -eq $true) { Ok "Servidor en Fly.io: $flyApp" }
  elseif ($enFly -eq $false) { Nota "No hay servidor '$flyApp' en tu Fly.io" }
  else { Aviso "No he podido preguntar a Fly.io por '$flyApp'; intentare borrarlo igual" }
  $copia = Join-Path (Carpeta-Copias) $App
  $hayCopia = Test-Path $copia

  $driveEstado = "sin-datos"
  if ($baja -and $baja.drive -eq "papelera") { $driveEstado = "papelera" }
  elseif ($driveId) { $driveEstado = "pendiente" }
  elseif ($nac -and $nac.drive -eq $false) { $driveEstado = "sin-drive" }

  Write-Host ""
  Write-Host "   SE BORRA, PARA SIEMPRE:" -ForegroundColor Red
  if ($enFly -ne $false) { Rojo "x  el servidor en Fly.io   $flyApp" }
  if ($r) { Rojo "x  tu app en GitHub         https://github.com/$($script:repo)"; Rojo "   (el codigo, su historia, la web y la bitacora)" }
  Write-Host ""
  Write-Host "   SE QUEDA:" -ForegroundColor Green
  if ($hayCopia) { Dice "+  tu copia en este PC      $copia"; Dice "   Es tuya: guardala como copia de seguridad o borrala tu." }
  else { Dice "+  tu copia del PC, si la tienes en otro ordenador" }
  Dice "+  tus cuentas, tu organizacion y su llave de Fly.io (para otras apps)"
  if ($driveEstado -eq "papelera") { Dice "+  Drive: Claude ya mando tu carpeta a la papelera" }
  elseif ($driveEstado -eq "pendiente") { Aviso "Drive: tu carpeta sigue ahi. Al terminar te la abro para que la borres." }

  if (-not $r -and $enFly -eq $false) {
    Write-Host ""
    Ok "No queda nada que borrar de '$App' en GitHub ni en Fly.io."
    Lo-Que-Queda-Eliminar $App $copia $hayCopia $driveEstado $driveId
    return
  }
  if ($Simular) { Write-Host ""; Write-Host "   Simulacion (-Simular): no se ha borrado nada." -ForegroundColor Cyan; return }

  Write-Host ""
  Write-Host "   Esto NO se puede deshacer." -ForegroundColor White -BackgroundColor DarkRed
  Dice "Para seguir, escribe el nombre de tu app y pulsa Intro."
  Dice "Para no borrar nada, cierra esta ventana."
  if (-not (Confirmar "Nombre de la app ($App)" $App)) {
    Write-Host ""
    Ok "No coincide: no se ha borrado nada."
    return
  }

  # ------------------------------------------------------------ 5/6 Borrar
  Paso "5/6 Borrando"
  $script:hecho.confirmado = $true
  if ($enFly -ne $false) {
    $f = Fly-Destruir $flyApp
    if ($f -eq "borrada") { Ok "Servidor '$flyApp' borrado de Fly.io" } else { Ok "El servidor '$flyApp' ya no existia" }
  }
  $script:hecho.fly = $true
  if ($r) {
    $g = Gh @("repo", "delete", $script:repo, "--yes")
    if (-not $g.ok -and $g.texto -match "delete_repo") {
      Autorizar @("auth", "refresh", "--hostname", "github.com", "--scopes", "delete_repo")
      $g = Gh @("repo", "delete", $script:repo, "--yes")
    }
    if (-not $g.ok) { Falla "GitHub no deja borrar $($script:repo): $($g.texto)" @("El servidor ya esta borrado. Vuelve a abrir el archivo para terminar.") }
    Ok "$($script:repo) borrada de GitHub, con su web y su bitacora"
  }
  $script:hecho.repo = $true

  # ------------------------------------------------------------ 6/6 Comprobacion
  Paso "6/6 Comprobacion"
  if (Leer-Repo $script:repo) { Aviso "GitHub aun ensena $($script:repo): mira https://github.com/$($script:repo)/settings" }
  else { Ok "GitHub: $($script:repo) ya no existe" }
  $sigue = Fly-Existe $flyApp
  if ($sigue -eq $true) { Aviso "Fly.io aun ensena '$flyApp': mira https://fly.io/dashboard" }
  elseif ($sigue -eq $false) { Ok "Fly.io: '$flyApp' ya no existe" }
  $web = "https://$($Org.ToLowerInvariant()).github.io/$App/"
  $apagada = Esperar "Esperando a que se apague la web" { $h = Http $web; if (-not $h -or $h.codigo -ne 200) { "ok" } } 2
  if ($apagada) { Ok "La web ya no se publica" } else { Nota "La web tardara unos minutos mas en desaparecer (cache de GitHub)" }

  $mins = [Math]::Round(((Get-Date) - $script:inicio).TotalMinutes, 1)
  Write-Host ""
  Write-Host ("================ {0} eliminada en {1} min ================" -f $App, $mins) -ForegroundColor White -BackgroundColor DarkRed
  Lo-Que-Queda-Eliminar $App $copia $hayCopia $driveEstado $driveId
  Write-Host ""
  Fuerte "Vuelve al movil: la eliminacion se marca sola."
}
function Lo-Que-Queda-Eliminar([string]$App, [string]$copia, [bool]$hayCopia, [string]$driveEstado, [string]$driveId) {
  Write-Host ""
  if ($hayCopia) {
    Fuerte "Tu copia sigue en este PC:"
    Dice   "  $copia"
    Dice   "  (y su acceso 'Peripateticos - $App' en el escritorio)."
    Dice   "  Es tuya y nadie la va a tocar: guardala como copia de seguridad"
    Dice   "  o borrala tu cuando quieras. 'Actualizar copia' ya no funcionara."
  }
  if ($driveEstado -eq "pendiente") {
    Write-Host ""
    Aviso "Tu carpeta de Google Drive sigue ahi. Te la abro en el navegador:"
    Dice  "  boton derecho sobre ella -> Mover a la papelera."
    Abrir "https://drive.google.com/drive/folders/$driveId"
  } elseif ($driveEstado -eq "sin-datos") {
    Write-Host ""
    Nota "Si tu app tenia carpeta en Google Drive y Claude no la borro, mandala tu a la papelera."
  }
  Nota "Tus conversaciones con Claude sobre esta app siguen en claude.ai/code; archivalas si quieres."
}

# ================================================================ Renombrar
function Renombrar {
  $App = $script:App; $Org = $script:Org; $Nuevo = $script:Nuevo
  Encabezado ("Peripateticos :: renombrar `"$App`" a `"$Nuevo`"") "Cambia el nombre en GitHub, la web, Fly.io y tu PC." DarkBlue

  Paso "1/7 Ayudantes"
  Ayudantes
  Paso "2/7 Entrar en GitHub"
  Entrar-GitHub @("repo")
  Paso "3/7 Entrar en Fly.io"
  Entrar-Fly

  # ------------------------------------------------------------ 4/7 Que hay
  Paso "4/7 Lo que hay"
  $viejo = Leer-Repo "$Org/$App"
  $nuevoR = Leer-Repo "$Org/$Nuevo"
  $hecho = $false
  if ($viejo -and $viejo.name -ieq $Nuevo) { $hecho = $true; $r = $viejo }
  elseif ($viejo -and $nuevoR) { Falla "Ya tienes otra app llamada '$Nuevo' en $Org." @("Vuelve al movil y elige otro nombre.") }
  elseif ($viejo) { $r = $viejo }
  elseif ($nuevoR) {
    $script:repo = "$Org/$Nuevo"
    $n = Leer-Json "docs/nacimiento.json"
    if ($n -and $n.renombrado -and "$($n.renombrado.de)" -ieq $App) { $hecho = $true; $r = $nuevoR }
    else { Falla "No encuentro $Org/$App, y '$Nuevo' ya es otra app." @("Revisa los nombres en el movil.") }
  }
  else { Falla "No encuentro la app $Org/$App en GitHub." @("Revisa el nombre y la organizacion en el movil.") }
  if (-not $hecho -and $r.name -ine $App) { Falla "La app '$App' ahora se llama '$($r.name)'." @("Vuelve al movil y elige '$($r.name)'.") }
  Comprobar-Repo $r $App
  $script:repo = $r.full

  $flyViejo = NombreFly "$App-$Org"
  $v = Gh @("variable", "get", "FLY_APP", "-R", $script:repo) -SoloSalida
  if ($v.ok -and $v.texto) { $flyViejo = $v.texto.Trim() }
  $flyNuevo = NombreFly "$Nuevo-$Org"
  if ($hecho -and $flyViejo -eq $flyNuevo) { $flyViejo = NombreFly "$App-$Org" }
  $flyOrg = ""
  $fo = Gh @("variable", "get", "FLY_ORG", "-R", $script:repo) -SoloSalida
  if ($fo.ok -and $fo.texto) { $flyOrg = $fo.texto.Trim() }
  if (-not $flyOrg) { $fo = Gh @("variable", "get", "FLY_ORG", "--org", $Org) -SoloSalida; if ($fo.ok -and $fo.texto) { $flyOrg = $fo.texto.Trim() } }
  if (-not $flyOrg) { $flyOrg = "personal" }

  $orgMin = $Org.ToLowerInvariant()
  $webV = "https://$orgMin.github.io/$App/"; $webN = "https://$orgMin.github.io/$Nuevo/"
  $srvN = "https://$flyNuevo.fly.dev/"
  $raiz = Carpeta-Copias
  $copiaV = Join-Path $raiz $App; $copiaN = Join-Path $raiz $Nuevo

  Write-Host ""
  Fuerte "Esto es lo que va a cambiar:"
  Dice "GitHub    $Org/$App  ->  $Org/$Nuevo"
  Dice "Web       $webV"
  Dice "         ->  $webN   (la direccion vieja deja de funcionar)"
  Dice "Servidor  $flyViejo  ->  $flyNuevo"
  Dice "          Fly.io no deja cambiar nombres: creo uno nuevo con tu app"
  Dice "          y borro el viejo cuando el nuevo responda."
  if ((Test-Path $copiaV) -or (Test-Path $copiaN)) { Dice "Tu PC     $copiaV  ->  $Nuevo" }
  Dice "Drive     lo cambia Claude, en el movil, despues de esto"
  if ($hecho) { Nota "GitHub ya se llama '$Nuevo': sigo donde lo deje." }
  if ($Simular) { Write-Host ""; Write-Host "   Simulacion (-Simular): no se ha cambiado nada." -ForegroundColor Cyan; return }

  if (-not $hecho) {
    Write-Host ""
    Dice "Para seguir, escribe el nombre nuevo y pulsa Intro."
    Dice "Para no cambiar nada, cierra esta ventana."
    if (-not (Confirmar "Nombre nuevo ($Nuevo)" $Nuevo)) { Write-Host ""; Ok "No coincide: no se ha cambiado nada."; return }
  }

  # ------------------------------------------------------------ 5/7 Cambio
  Paso "5/7 Cambiando el nombre"
  # Primero el servidor nuevo: si el nombre esta cogido en Fly.io, se para aqui sin tocar nada.
  $c = Fly @("apps", "create", $flyNuevo, "--org", $flyOrg)
  if ($c.ok) { Ok "Nombre '$flyNuevo' reservado en Fly.io" }
  elseif ($c.texto -match "taken|already|exists") {
    $mias = Fly @("apps", "list", "--json") -SoloSalida
    if ($mias.texto -match ('"' + [regex]::Escape($flyNuevo) + '"')) { Ok "El nombre '$flyNuevo' ya era tuyo en Fly.io" }
    else { Falla "El nombre '$flyNuevo' esta cogido por otra persona en Fly.io. No se ha cambiado nada." @("Vuelve al movil y elige otro nombre.") }
  } else { Falla "Fly.io no deja crear el servidor nuevo: $($c.texto)" @("Vuelve a abrir el archivo. No se ha cambiado nada.") }
  $script:hecho.fly = $true

  if (-not $hecho) {
    $p = Gh @("api", "-X", "PATCH", "repos/$Org/$App", "-f", "name=$Nuevo", "--silent")
    if (-not $p.ok) { Falla "GitHub no deja cambiar el nombre: $($p.texto)" @("Vuelve a abrir el archivo.") }
    Ok "GitHub: $Org/$App ahora es $Org/$Nuevo"
  }
  $script:repo = "$Org/$Nuevo"
  $script:hecho.repo = $true
  if (-not (Gh @("variable", "set", "FLY_APP", "-R", $script:repo, "--body", $flyNuevo)).ok) { Falla "No se pudo anotar el servidor nuevo en el repositorio." @("Vuelve a abrir el archivo.") }

  # CLAUDE.md (la fila del servidor) y nacimiento.json: los leen Claude, el movil y la portada.
  $driveId = ""
  $cm = Leer-Fichero "CLAUDE.md"
  if ($cm) {
    $driveId = Id-Drive $cm.texto
    $t = [regex]::Replace($cm.texto, '(?m)^(\| App de Fly\.io \|).*$', ('$1 `' + $flyNuevo + '` |'))
    if ($t -ne $cm.texto) { if (Escribir-Fichero "CLAUDE.md" $t $cm.sha "Anotar el servidor nuevo: $flyNuevo") { Ok "CLAUDE.md apunta al servidor nuevo" } }
  }
  $nf = Leer-Fichero "docs/nacimiento.json"
  if ($nf) {
    try {
      $n = $nf.texto | ConvertFrom-Json
      $n.app = $Nuevo; $n.repo = $script:repo; $n.web = $webN; $n.servidor = $srvN; $n.fly_app = $flyNuevo
      $n | Add-Member -NotePropertyName renombrado -NotePropertyValue ([ordered]@{ de = $App; fecha = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") }) -Force
      if (Escribir-Fichero "docs/nacimiento.json" ($n | ConvertTo-Json -Depth 4) $nf.sha "Registrar el nombre nuevo: $Nuevo") { Ok "Registro de la app al dia" }
    } catch { Aviso "No se pudo poner al dia docs/nacimiento.json (no es grave)" }
  }
  # El nombre con el que se presenta el servidor ("Hola, soy ..."). Va el
  # ultimo: este commit es el que construye el servidor nuevo y publica la web.
  $sha = $null; $esperaClaude = $false
  $mr = Leer-Fichero "app/src/main.rs"
  if ($mr -and $mr.texto -match ('const NOMBRE: &str = "' + [regex]::Escape($App) + '";')) {
    $t = $mr.texto.Replace(('const NOMBRE: &str = "' + $App + '";'), ('const NOMBRE: &str = "' + $Nuevo + '";'))
    $sha = Escribir-Fichero "app/src/main.rs" $t $mr.sha "Cambiar el nombre del servidor a $Nuevo"
    if (-not $sha) { Falla "No se pudo cambiar el nombre en el servidor." @("Vuelve a abrir el archivo.") }
    Ok "El servidor se presentara como '$Nuevo'"
  } elseif ($mr -and $mr.texto -match ('const NOMBRE: &str = "' + [regex]::Escape($Nuevo) + '";')) {
    Nota "El servidor ya se presenta como '$Nuevo'"
  } else {
    $esperaClaude = $true
    Aviso "No encuentro el nombre del servidor en app/src/main.rs: lo cambiara Claude."
  }

  # ------------------------------------------------------------ 6/7 Servidor nuevo
  Paso "6/7 Servidor nuevo"
  $urlSrv = $srvN; if ($env:PERI_URL_SERVIDOR) { $urlSrv = $env:PERI_URL_SERVIDOR }
  $urlWeb = $webN; if ($env:PERI_URL_WEB) { $urlWeb = $env:PERI_URL_WEB }
  $nuevoLocal = $Nuevo
  if ($sha) {
    Nota "Construyendo el servidor nuevo. Tarda entre 2 y 5 minutos; no es un fallo."
    $dep = Esperar-Run "deploy.yml" $sha "Construyendo el servidor nuevo" $TimeoutMin
    Ok "Servidor nuevo construido ($($dep.url))"
  }
  $hola = Hola $urlSrv
  if (-not ($hola -and "$($hola.app)" -ieq $Nuevo)) {
    if ($esperaClaude) {
      Fuerte "Ahora, en el movil, haz el paso de Claude (cambiar los textos)."
      Fuerte "Espero aqui a que tu servidor nuevo responda (hasta 30 minutos)."
      $hola = Esperar "Esperando al servidor nuevo" { $h = Hola $urlSrv; if ($h -and "$($h.app)" -ieq $nuevoLocal) { $h } } 30
    } elseif (-not $sha) {
      $l = Gh @("workflow", "run", "deploy.yml", "-R", $script:repo, "--ref", "main")
      if ($l.ok) { Nota "Construyendo el servidor nuevo. Tarda entre 2 y 5 minutos." }
      $hola = Esperar "Esperando al servidor nuevo" { $h = Hola $urlSrv; if ($h -and "$($h.app)" -ieq $nuevoLocal) { $h } } $TimeoutMin
    } else {
      $hola = Esperar "Esperando al servidor nuevo" { $h = Hola $urlSrv; if ($h -and "$($h.app)" -ieq $nuevoLocal) { $h } } 3
    }
  }
  if (-not $hola) { Falla "El servidor nuevo aun no responde en $($srvN)hola." @("El viejo sigue encendido: no se ha perdido nada.", "Vuelve a abrir el archivo dentro de unos minutos (o cuando Claude termine).") }
  Ok ('"' + $hola.mensaje + '"')
  if ($flyViejo -ne $flyNuevo) {
    $f = Fly-Destruir $flyViejo
    if ($f -eq "borrada") { Ok "Servidor viejo '$flyViejo' borrado" } else { Ok "El servidor viejo '$flyViejo' ya no existia" }
  }
  $script:hecho.servidor = $true
  if ($sha) { $pag = Esperar-Run "pages.yml" $sha "Publicando la web nueva" 10 }
  $w = Esperar "Esperando a la web nueva" { $h = Http $urlWeb; if ($h -and $h.codigo -eq 200) { $h } } 5
  if ($w) { Ok "Web nueva: $webN" } else { Aviso "La web nueva aun no responde (a veces tarda unos minutos): $webN" }

  # ------------------------------------------------------------ 7/7 Copia en el PC
  Paso "7/7 Copia en tu PC"
  $carpeta = $null
  if (Test-Path $copiaN) { $carpeta = $copiaN; Nota "La copia ya se llama '$Nuevo'" }
  elseif (Test-Path $copiaV) {
    try { Rename-Item -LiteralPath $copiaV -NewName $Nuevo -ErrorAction Stop; $carpeta = $copiaN; Ok "Carpeta renombrada: $copiaN" }
    catch {
      Aviso "No he podido cambiar el nombre de la carpeta: $($_.Exception.Message)"
      Dice  "Hazlo tu: cierra las ventanas que la tengan abierta, ve a"
      Dice  "  $raiz"
      Dice  "y en '$App': boton derecho -> Cambiar nombre -> $Nuevo."
      Dice  "Despues, doble clic en 'Actualizar copia.cmd' dentro de ella."
    }
  } else { Nota "No hay copia de '$App' en este PC: nada que renombrar." }
  if ($carpeta) {
    try {
      Get-ChildItem -LiteralPath $carpeta -Filter "*.url" | Remove-Item -Force -ErrorAction SilentlyContinue
      $fichaV = Join-Path $carpeta "$App.txt"; if (Test-Path $fichaV) { Remove-Item -Force $fichaV }
      Preparar-Copia $carpeta $Nuevo $script:repo $webN $srvN $driveId
      $esc = Escritorio
      if ($esc -and (Test-Path $esc)) {
        $lnkV = Join-Path $esc "Peripateticos - $App.lnk"
        if (Test-Path $lnkV) { Remove-Item -Force $lnkV }
        try {
          $wsh = New-Object -ComObject WScript.Shell
          $lnk = $wsh.CreateShortcut((Join-Path $esc "Peripateticos - $Nuevo.lnk")); $lnk.TargetPath = $carpeta; $lnk.Save()
          Ok "Acceso del escritorio con el nombre nuevo"
        } catch { }
      }
    } catch { Aviso "No se pudo poner al dia la copia: $($_.Exception.Message). Doble clic en 'Actualizar copia.cmd'." }
  }

  $mins = [Math]::Round(((Get-Date) - $script:inicio).TotalMinutes, 1)
  Write-Host ""
  Write-Host ("================ {0} ahora es {1} ({2} min) ================" -f $App, $Nuevo, $mins) -ForegroundColor Green
  Dice ("Web         " + $webN)
  Dice ("Servidor    " + $srvN)
  Dice ("Donde vive  https://github.com/" + $script:repo)
  if ($carpeta) { Dice ("Copia       " + $carpeta) }
  Write-Host ""
  Fuerte "Vuelve al movil: falta que Claude cambie el nombre en los textos"
  Fuerte "de tu app y en tu carpeta de Drive. Ya puedes apagar el PC."
  Abrir $webN
}

# ================================================================ Arranque
$script:Accion = "$Accion".Trim().ToLowerInvariant()
$script:App    = Slug $App
$script:Nuevo  = Slug $Nuevo
$script:Org    = "$Org".Trim() -replace '^@', '' -replace '[^A-Za-z0-9-]', ''
if (-not $Bin) {
  if ($env:LOCALAPPDATA) { $Bin = Join-Path $env:LOCALAPPDATA "Peripateticos\bin" }
  else { $Bin = Join-Path $HOME ".peripateticos/bin" }
}
try { $Host.UI.RawUI.WindowTitle = "Peripateticos - $($script:Accion) $($script:App)" } catch { }

try {
  if ($PSVersionTable.PSVersion.Major -lt 5) { Falla "Este Windows es demasiado antiguo (PowerShell $($PSVersionTable.PSVersion))." @("Hace falta Windows 10 u 11.") }
  if (-not $script:App -or -not $script:Org) { Falla "Faltan el nombre de la app o el de la organizacion." @("Descarga el archivo otra vez desde la pagina del movil.") }
  if ($script:Accion -eq "eliminar") { Eliminar }
  elseif ($script:Accion -eq "renombrar") {
    if (-not $script:Nuevo -or $script:Nuevo.Length -lt 2) { Falla "Falta el nombre nuevo." @("Descarga el archivo otra vez desde la pagina del movil.") }
    if ($script:Nuevo -eq $script:App) { Falla "El nombre nuevo es el mismo que el de ahora." @("Elige otro en el movil.") }
    Renombrar
  }
  else { Falla "No se que hacer: '$($script:Accion)'." @("Descarga el archivo otra vez desde la pagina del movil.") }
} catch {
  Write-Host ""
  Write-Host "   XX  $($_.Exception.Message)" -ForegroundColor Red
  foreach ($l in $script:ayuda) { Write-Host "       $l" -ForegroundColor Yellow }
  if ($script:hecho.Count -gt 0) {
    Write-Host ""
    Dice "Vuelve a abrir el mismo archivo: sigue donde lo dejo."
  }
}
