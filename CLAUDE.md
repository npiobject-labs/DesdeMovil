# DesdeMovil — instrucciones del proyecto

Flujo "PC arranca, móvil continúa": el desarrollo, la revisión y las pruebas se hacen desde sesiones en la nube (claude.ai/code con este repo seleccionado, desde web o móvil), con el PC apagado. Trabaja en español. Perfil del usuario: desarrollador senior en solitario; no expliques conceptos básicos; marca toda suposición no verificada como [SUPUESTO] e indica su plan B.

## Fuentes de verdad (en este orden)

1. Este repositorio, `npiobject/DesdeMovil`, rama `main`.
2. Google Drive, carpeta normal `Mi unidad/DesdeMovil` (id `1-0wWhp_-rrSgxKrr0AN34dg_Y2nAPK2J`). Nunca uses el "Proyecto" de Drive del mismo nombre: el conector no puede escribir en él.
3. La carpeta local del PC es un espejo de solo lectura. Nunca la trates como origen ni construyas un camino local → nube.

## Código

- Todo cambio termina en commit + push a `main`. Mensajes de commit en español, imperativo.
- Mocks estáticos en `docs/`. `docs/index.html` es el mock vivo; los anteriores se archivan en `docs/mocks/NNN-nombre.html`.
- Cada mock lleva `<meta name="build" content="DM-B3-AAAAMMDD-NNN">` con un número nuevo en cada iteración.
- Nunca pongas claves, endpoints internos ni datos reales en `docs/`: el sitio es público.

## Documentación

- Cada documento de planificación, decisión o resumen de sesión se guarda en dos sitios: `docs/planificacion/` en este repo y la carpeta de Drive.
- A Drive se sube como fichero, sin conversión a formato Google (`disableConversionToGoogleType=true`), tanto `.md` como `.html/.png/.svg`.
- No hay edición incremental en Drive: regenera y vuelve a subir con el mismo nombre y sufijo de versión (`-v2`, `-v3`).

## Despliegue

- Fase de mocks: GitHub Pages vía `.github/workflows/pages.yml` (push a `main` publica `docs/`). URL: https://npiobject.github.io/DesdeMovil/
- Fase con backend: el VPS hace pull de la rama `release` cada 2 minutos. Solo tocas `release` cuando el usuario lo pida explícitamente.
- No intentes SSH, scp, rsync ni curl al VPS ni a `*.github.io` desde la sesión: el sandbox los bloquea.

## Verificación antes de avisar

- No anuncies "puedes probarlo" hasta confirmar por la API de GitHub Actions que el run del workflow para el SHA que acabas de enviar está en `success` (en fase backend: que `deploy/status.json` de la rama `deploy-status` referencia ese SHA).
- Si en 5 minutos no está, avisa del fallo con la causa leída en los logs, no del éxito.
- Al avisar, da siempre: SHA, URL y número de `build`.

## Aterrizaje en el PC

- Solo a petición y solo con Claude Desktop conectado: `tools/aterrizar.ps1` (idempotente, sobrescribe la copia local sin preguntar). "¿Estoy al día?" = `tools/estado.ps1`.

## Cierre de sesión

- Termina cada sesión con un resumen de 5 líneas (qué cambió, SHA, URL para probar, resultado en Drive, qué falta) y súbelo a Drive en `sesiones/AAAAMMDD-HHMM.md` y al repo en `docs/planificacion/sesiones/`.
