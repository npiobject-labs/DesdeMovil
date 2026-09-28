# DesdeMovil — instrucciones del proyecto

Flujo "PC arranca, móvil continúa": el desarrollo, la revisión y las pruebas se hacen desde sesiones en la nube (claude.ai/code con este repo seleccionado, desde web o móvil), con el PC apagado. Trabaja en español. Perfil del usuario: desarrollador senior en solitario; no expliques conceptos básicos; marca toda suposición no verificada como [SUPUESTO] e indica su plan B.

## Parámetros

| Parámetro | Valor |
|---|---|
| Proyecto | `DesdeMovil` |
| Owner de GitHub | `npiobject-labs` |
| App de Fly.io | `derivada` |
| Carpeta de Drive (id) | `1-0wWhp_-rrSgxKrr0AN34dg_Y2nAPK2J` |

Esta tabla la rellena sola `.github/workflows/init-plantilla.yml` en el primer push de un repo creado desde la plantilla; no hay nada que tocar a mano salvo el id de Drive. Si la app se montó con el instalador de Peripatéticos, él anota también la app de Fly y, si se le dio, la carpeta de Drive.

- **App de Fly.io**: `derivada` significa que `deploy.yml` la calcula como `<repo>-<owner>` en minúsculas, saneado a `[a-z0-9-]` y recortado a 30 caracteres. Si existe la variable de repositorio `FLY_APP`, esa manda; anota aquí el valor cuando la definas.
- **Carpeta de Drive (id)**: vacío significa que este proyecto no usa Drive. Ver ARRANQUE.md para activarlo a mitad de proyecto.

## Fuente de verdad

El repositorio `npiobject-labs/DesdeMovil`, rama `main`, es la **única** fuente de verdad, tanto para el código como para la documentación de `docs/planificacion/`. Todo lo que importe vive aquí y se edita aquí.

Google Drive es **opcional** y, cuando está configurado, **solo un destino de copias**, nunca un origen:

- Si el id de la sección **Parámetros** está vacío, este proyecto no usa Drive: omite el paso sin comentarlo.
- Si hay id, al cerrar sesión se suben copias de `docs/planificacion/` a esa carpeta. Solo crear o sobrescribir por nombre: nunca borrar ni renombrar nada en Drive, salvo lo que describe **Eliminar o renombrar la app**, y solo cuando el usuario lo pide.
- Nunca se toma nada de Drive como origen ni se importa contenido desde allí. Si el repo y Drive difieren, gana el repo.
- La carpeta tiene que ser una carpeta normal de `Mi unidad`. Nunca uses el "Proyecto" de Drive del mismo nombre: el conector no puede escribir en él.

La carpeta local del PC es un espejo de solo lectura. Nunca la trates como origen ni construyas un camino local → nube.
<!-- solo-plantilla -->

## Producto nuevo: preguntas pendientes

Desde el 28-09-2026 se planifica un producto nuevo a partir de Peripatéticos (infraestructura limpia, niveles de prueba y premium, alta sin PC, botón de ayuda, pasarela de IA). Como lleva estrategia y precios, su documento base vive **solo** en Drive, en la carpeta de **Parámetros**: `Peripatéticos · proyecto inicial (vN).md`, la versión más alta. Es la única excepción, decidida por el usuario, a «Drive nunca es origen»; no se copia a `docs/`, que es público.

En cada sesión, léelo con el conector de Google Drive y pregunta al usuario las **Preguntas pendientes** que sigan abiertas, en orden y como mucho tres cada vez, aunque no las mencione: ha pedido que seas tú quien pregunte, porque se le olvidan. Anota las respuestas en **Decisiones tomadas** y sube el documento completo como versión nueva. Sin conector, pídele que conecte Google Drive. `init-plantilla.yml` quita esta sección en los proyectos hijos.
<!-- /solo-plantilla -->

## URLs vivas

| Qué | URL | Despliegue |
|---|---|---|
| Portada (Pages; en la plantilla, el menú de Peripatéticos) | https://npiobject-labs.github.io/DesdeMovil/ | `.github/workflows/pages.yml` en push a `main` |
| Bitácora (Pages) | https://npiobject-labs.github.io/DesdeMovil/bitacora.html | idem; el índice lo genera `pages.yml` |
| Backend (Fly.io, opcional) | `https://<app de Fly>.fly.dev/` · `/salud` · `/holamundo` | `.github/workflows/deploy.yml` en push a `main` que toque `app/**` |
| Comprobación del backend (Pages) | https://npiobject-labs.github.io/DesdeMovil/holamundo.html | página estática que llama a `/holamundo` y `/salud` desde el navegador |

Pages está siempre activo. Fly también: `FLY_API_TOKEN` es un secreto de la organización `npiobject-labs` y lo heredan sus repos **públicos**, así que `deploy.yml` despliega sin configurar nada. Si el repo fuera privado (plan Free) o viviera fuera de la organización, el secreto no llega y `deploy.yml` termina en verde con el aviso "Fly no configurado" sin desplegar nada.

## Código

- Todo cambio termina en commit + push a `main`. Mensajes de commit en español, imperativo.
- Backend en `app/` (Rust, axum + tokio). `GET /` devuelve texto plano; `GET /salud` devuelve `{"ok":true,"build":"<BUILD_ID>"}`, donde `BUILD_ID` es el SHA que inyecta el workflow.
- `GET /holamundo` devuelve `holamundo` en texto plano; `/holamundo` y `/salud` llevan `Access-Control-Allow-Origin: *` porque los consume `docs/holamundo.html` desde Pages (otro origen). Si añades más rutas para el frontend, ponles la misma cabecera.
- `GET /hola` es el saludo de la app: JSON con `app` (el nombre del proyecto), `mensaje` («Hola, soy … y respondo desde Fly.io»), `fecha` ISO en UTC, `region`, `maquina`, `app_fly`, `version` (el SHA) y `despierta_desde_hace_s`, con la misma cabecera CORS. Lo consumen el botón «Saluda» de la portada y el instalador. `deploy.yml` verifica las tres rutas y falla si cambian.
- `docs/holamundo.html` toma el nombre de la app de Fly del `<meta name="fly-app">` (`<repo>-<owner>`, como lo deriva `deploy.yml`). Si el proyecto define `FLY_APP` con otro nombre, actualiza ese `content` en el mismo commit.
- `app/fly.toml` no lleva clave `app`: el nombre se pasa con `--app` desde `deploy.yml`.
- El backend escucha en 8080, que es lo que espera Fly; la variable de entorno `PUERTO` solo la usa `tools/arrancar.ps1` para probar en el PC.
- Mocks estáticos en `docs/`. `docs/index.html` es el mock vivo; los anteriores se archivan en `docs/mocks/NNN-nombre.html`.
- En la plantilla, `docs/index.html` es el **menú de Peripatéticos**, que enlaza todo lo demás: `docs/instalar.html` (portada + instalador con verificación real, ficha, pedir y ayuda; los enlaces viejos a la raíz con `#instalar`, `#ayuda` o `?u=…&org=…` se redirigen allí), `docs/renombrar.html` (cambiar el nombre de una app), `docs/desinstalar.html` (eliminarla, con estética de zona de peligro), `docs/pc.html` (la página que se abre en el PC y genera el `.cmd`; `?accion=eliminar` o `?accion=renombrar&nuevo=…` cambian lo que hace), `docs/instalador/peripateticos.ps1` (el instalador), `docs/instalador/mantenimiento.ps1` (eliminar y renombrar desde el PC) y `docs/recorrido.html` (las pantallas del recorrido). Todas ellas cargan `docs/menu.js` en el `<head>`, como `menu.js?b=<build>` (al cambiar `menu.js`, sube el build de esas páginas y ese `?b=`, o los navegadores siguen usando el viejo hasta 10 minutos): pone el botón **Menú** (≡) en la barra `.top`, con todas las opciones y **Empezar de cero** (dejar la app a medias y empezar otra, que `instalar.html` hace al recibir `?nueva=1` conservando las cuentas ya comprobadas; o borrar todo lo guardado en el navegador), y da estilo al recuadro `.pm-intro` («Qué hace esta página», un `<details>` plegado con `<summary class="pm-t">…<span class="pm-flecha"><svg>…</svg></span></summary>` que se despliega al tocarlo) con el que empieza cada página o pantalla, en lenguaje llano. También hace flotar la barra `.top` de cada página y la cabecera del menú ≡: al desplazar, se estrechan, se vuelven algo transparentes y proyectan una sombra de hoja curvada, máxima en el centro y nula en los bordes (oscura de día, clara de noche); en el borde inferior de la barra de la página va la línea de progreso de lectura (`.pm-progreso`), del color de la marca. Y hace aparecer con un fundido suave las tarjetas que están por debajo de la pantalla al cargar (`.ops > li`, `.paso`, `.demo`…), salvo si el sistema pide reducir animaciones. Una página nueva de la plantilla lleva los dos; `init-plantilla.yml` borra `menu.js` en los hijos.
- **Las páginas que ve el cliente no enlazan nada del desarrollo de Peripatéticos**: ni la bitácora, ni `docs/planificacion/`, ni `mocks/`, ni las guías técnicas (`guia*.html`), ni `holamundo.html`, ni el repositorio en GitHub. Esas páginas siguen publicadas para nosotros, pero sin enlaces desde el menú, el menú ≡, los pies ni la vista previa de `semilla/`. La ficha de la app de un cliente sí enlaza **su** bitácora. La copia limpia (paso 2) está en `docs/planificacion/deuda-tecnica.md` (DT-1). `docs/semilla/index.html` es la portada con la que nace cada proyecto: `init-plantilla.yml` la mueve a `docs/index.html` y borra lo demás, que solo tiene sentido aquí. En cada proyecto, `docs/nacimiento.json` lo escribe el instalador (y lo pone al día `mantenimiento.ps1` al renombrar) y `docs/drive.json` la sesión que comprueba Drive (ver **Comprobación de Drive**); los dos los leen la portada y el instalador. `docs/baja.json` y `docs/renombrado.json` los escribe la sesión de Claude de **Eliminar o renombrar la app**.
- El índice `docs/mocks/index.html` lo genera `pages.yml` en cada publicación, leyendo el `<title>` y el `<meta name="build">` de cada mock archivado. No lo edites ni lo commitees: está en `.gitignore`.
- Cada mock lleva `<meta name="build" content="DM-B3-AAAAMMDD-NNN">` con un número nuevo en cada iteración.
- Nunca pongas claves, endpoints internos ni datos reales en `docs/`: el sitio es público.

## Documentación

- Cada documento de planificación, decisión o resumen de sesión se escribe en `docs/planificacion/` de este repo, y solo ahí se edita.
- Lo que se aplaza a propósito va en `docs/planificacion/deuda-tecnica.md`, con el porqué y el plan. Consúltalo antes de proponer cambios de fondo.
- Si existe `docs/plantilla/`, es el historial de la plantilla de origen que apartó `init-plantilla.yml`: referencia de solo lectura, nunca se edita ni se mezcla con `docs/planificacion/`.
- Si hay id de Drive en **Parámetros**, al cerrar sesión se sube copia como fichero, sin conversión a formato Google (`disableConversionToGoogleType=true`), tanto `.md` como `.html/.png/.svg`.
- No hay edición incremental en Drive: se vuelve a subir el fichero completo con el mismo nombre, o con sufijo de versión (`-v2`, `-v3`) si quieres conservar la copia anterior.

## Comprobación de Drive

Solo una sesión de Claude con el conector de Google Drive llega a la carpeta: ni Pages ni el instalador del PC pueden. Cuando te pidan comprobar el acceso a Drive (el instalador de Peripatéticos lo pide en su último paso):

1. Toma el id de la fila **Carpeta de Drive (id)** de **Parámetros**. Si está vacía, dilo y no hagas nada más.
2. Con el conector de Google Drive, lista la carpeta (`search_files` con `parentId = '<id>'`). Si no tienes conector o falla, no lo des por bueno: escribe `docs/drive.json` con `{"verificado": false, "fecha": "<ISO con zona>", "motivo": "<qué falló, en una frase>"}`, publícalo y dile al usuario que conecte Google Drive en Claude (**Ajustes → Conectores → Google Drive**) y te lo vuelva a pedir.
3. Si llegas, sube a la carpeta `Ficha de <nombre del proyecto>.md`, sin conversión a formato Google: qué es la app y sus enlaces (web, servidor, bitácora, repositorio). Solo crear o sobrescribir por nombre.
4. Escribe `docs/drive.json` con `{"verificado": true, "fecha": "<ISO con zona>", "fichero": "<nombre de la ficha>"}`. Sin el id de la carpeta ni datos personales: `docs/` es público.
5. Commit + push a `main` y confirma por la API de Actions que `pages.yml` de ese SHA queda en `success`: la página del instalador y la portada de la app leen ese fichero desde Pages.

## Eliminar o renombrar la app

Lo guían `desinstalar.html` y `renombrar.html` de la plantilla. El PC (`mantenimiento.ps1`) hace GitHub, Fly.io y la copia local; Claude, lo que solo él alcanza. Las peticiones que dan esas páginas son autosuficientes (valen para proyectos nacidos antes de esta sección); esto es lo que esperan:

- **Eliminar** (antes de que el PC borre el repositorio): con el id de **Carpeta de Drive (id)**, manda esa carpeta a la papelera con el conector (`trash_file`), solo esa. Escribe `docs/baja.json` con `{"drive": "papelera" | "sin-drive" | "no", "fecha": "<ISO con zona>", "motivo": "<si no se pudo>"}`, commit y push a `main`. Sin resumen ni bitácora: la app se va a borrar.
- **Renombrar** (después del PC, en una sesión nueva con el repositorio ya renombrado): cambia el nombre viejo por el nuevo en todo el repositorio salvo `docs/bitacora/` antigua y `docs/plantilla/`, y el servidor viejo de Fly por el nuevo (fila **App de Fly.io**, `meta fly-app`). Con el conector, cambia el título de la carpeta de Drive (`update_file`) y el de `Ficha de <viejo>.md`. Escribe `docs/renombrado.json` con `{"de", "a", "fecha", "drive": "renombrada" | "sin-drive" | "no", "motivo"}`, commit y push a `main`, y cierra la sesión como siempre.
- Nunca el id de la carpeta ni datos personales en esos ficheros: `docs/` es público. Si el conector no puede, `"drive": "no"` con el motivo: la página le explica al usuario cómo hacerlo a mano.
- Fly.io no renombra apps: `mantenimiento.ps1` crea la nueva, cambia `FLY_APP`, la constante `NOMBRE` de `app/src/main.rs` (ese commit despliega el servidor nuevo) y destruye la vieja cuando la nueva responde.

## Verificación antes de avisar

**El sandbox de la sesión no alcanza Pages, Fly ni el VPS**: `curl` a `*.github.io`, `*.fly.dev` o al VPS devuelve `CONNECT tunnel failed, response 403`. Tampoco hay daemon de Docker. Por eso **la verificación de un despliegue la hace siempre un workflow**, que corre en el runner de GitHub y sí tiene salida a internet:

- `pages.yml` da por bueno el despliegue con el paso `deploy-pages`, **pero eso solo prueba que el artefacto se subió**, no que se esté sirviendo. Si tras el push aparece además un run `pages build and deployment` con un paso `Build with Jekyll`, el **Source** de Pages sigue en «Deploy from a branch»: el sitio sirve la raíz del repo (README en `/`, `docs/` colgando de `/docs/`) y los runs de `pages.yml` salen verdes sin efecto. Comprobarlo es parte de la verificación; el arreglo es manual, en Settings.
- `deploy.yml` tiene un paso final que hace `curl` a `/salud` y falla el run si la respuesta no contiene el SHA del commit.

No anuncies "puedes probarlo" hasta confirmar por la API de GitHub Actions que el run del workflow para el SHA que acabas de enviar está en `success`. Si en 5 minutos no está, avisa del fallo con la causa leída en los logs, no del éxito. Al avisar, da siempre: SHA, URL y número de `build`.

Si necesitas comprobar algo desde la sesión, hazlo contra la API de GitHub (`https://api.github.com/repos/npiobject-labs/DesdeMovil/actions/runs/...`), que sí es accesible.

`pages.yml` solo se puede validar en `main`: el entorno `github-pages` únicamente despliega desde la rama por defecto, así que un `workflow_dispatch` sobre una rama de trabajo no sirve de verificación. `deploy.yml` sí acepta cualquier rama.

## Despliegue

- Estático: GitHub Pages vía `.github/workflows/pages.yml` (push a `main` publica `docs/`). Requiere **Settings → Pages → Source: GitHub Actions** una vez a mano. Se aplica también a este repo: el sitio de la plantilla estuvo sirviendo el README hasta que se hizo.
- Backend (opcional): Fly.io vía `.github/workflows/deploy.yml`. `FLY_API_TOKEN` **llega heredado de la organización `npiobject-labs`** (secreto de organización, repos públicos); no hay que crear ni guardar ningún token por proyecto. Nunca lo imprimas en los logs.
- La organización de Fly la da la variable `FLY_ORG` (de la organización de GitHub o del repositorio); sin ella, la de la plantilla. `deploy.yml` no despliega un proyecto que aún tenga `.plantilla-pendiente`: lo lanza `init-plantilla.yml` al terminar, ya con el nombre puesto.
- Si el proyecto usa además un VPS con rama `release`, solo tocas `release` cuando el usuario lo pida explícitamente.
- No intentes SSH, scp, rsync ni curl al VPS, a Fly ni a `*.github.io` desde la sesión: el sandbox los bloquea.

## Aterrizaje en el PC

- Las apps montadas con el instalador de Peripatéticos tienen además una copia de seguridad en `Documentos\Peripateticos\<app>\` (el repositorio en `repo\`, bajado como zip de `main`, sin git), con la ficha, accesos directos y `Actualizar copia.cmd`. Es un espejo de solo lectura, como la carpeta de `aterrizar.ps1`: se sustituye entera al actualizar.
- Solo a petición y solo con Claude Desktop conectado: `tools/aterrizar.ps1` (idempotente, sobrescribe la copia local sin preguntar). "¿Estoy al día?" = `tools/estado.ps1`. Ambos aceptan `-Proyecto`, `-Owner`, `-Remote`, `-Root` y `-Rama`.
- `tools/arrancar.ps1` levanta la app entera en el PC sin tocar la nube: compila el backend, lo sirve en `localhost:8080` y publica `docs/` en `localhost:8081`. Acepta `-PuertoApi`, `-PuertoWeb`, `-Release` y `-SinNavegador`. Necesita Rust; no necesita Docker.
- `tools/eliminar.ps1` borra el proyecto entero: app de Fly, repositorio y copia local. Para las apps de Peripatéticos, el camino del usuario es `desinstalar.html`, que no toca la copia local. Sin `-Confirmar` solo enseña el plan; con él pide escribir el nombre. Drive y las sesiones quedan a mano. Solo se ejecuta si el usuario lo pide explícitamente.
- `tools/nuevo-proyecto-V1.ps1` y `tools/eliminar-proyecto-V1.ps1` **solo existen en esta plantilla**: dan de alta y de baja un proyecto entero (repositorio, Pages, app de Fly y clon local; Drive nunca se toca, solo se apunta su id). El primero enseña el plan y pide confirmación —`-Simular` lo enseña y termina—, es reanudable y verifica por HTTP al final; el segundo simula por defecto y solo borra con `-Confirmar`. `init-plantilla.yml` los borra en los proyectos hijos y no les aplica las sustituciones de nombre, porque sus valores por defecto (`-Plantilla`, `-FlyOrg`, `-Protegidos`) nombran a la plantilla y a la organización de Fly.
- Servidas desde `localhost`, las páginas de `docs/` llaman al backend local en vez de al de Fly, tomando el puerto de `?api=` (8080 por defecto). En Pages no cambia nada.

## Cierre de sesión

- Termina cada sesión con un resumen de 5 líneas (qué cambió, SHA, URL para probar, resultado en Drive, qué falta), guárdalo en el repo en `docs/planificacion/sesiones/AAAAMMDD-HHMM.md` y, si hay id de Drive, sube copia a Drive en `sesiones/`.
- Además, entrada nueva en `docs/bitacora/AAAAMMDD-HHMM.json` (ver sección **Bitácora**).

## Bitácora

Página pública: https://npiobject-labs.github.io/DesdeMovil/bitacora.html · formato en `docs/bitacora/README.md`.

BITACORA: al cerrar sesión, además del resumen en docs/planificacion/sesiones/,
crea SIEMPRE un fichero nuevo docs/bitacora/AAAAMMDD-HHMM.json. Nunca edites ni
borres entradas anteriores, y nunca toques docs/bitacora.html ni
docs/bitacora/index.json (lo genera el workflow de Pages).

Campos: fecha (ISO con zona), titulo, objetivo, prompts (array de objetos con
texto y nota opcional), cambios (array), sha, sha_completo, run (id del run de
Actions), mock (ruta relativa al mock archivado de esa sesión), build, pagina,
fly (URL de /salud o null), pendiente (array), enlaces (array de {texto,url}),
notas. Obligatorios: fecha y titulo; el workflow falla si faltan.

Los prompts son una transcripción fiel de lo que pidió el usuario en esa sesión,
en sus términos, no un resumen de lo que hiciste. Si la sesión fue larga y la
transcripción es aproximada, dilo en el campo notas.

docs/ es público: nunca copies a la bitácora prompts que contengan claves,
rutas internas, datos personales o nombres de clientes. Si un prompt los
contiene, resúmelo en su lugar y anótalo en notas.
