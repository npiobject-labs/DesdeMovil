# Fricciones de `ARRANQUE.md` detectadas al estrenar la plantilla

**Fecha:** 2026-09-06
**Prueba:** repo [`npiobject/PruebaPlantilla`](https://github.com/npiobject/PruebaPlantilla), creado con *Use this template* e inicializado en una sesión de Code siguiendo `ARRANQUE.md` al pie de la letra.
**Resultado de la prueba:** los dos despliegues quedaron vivos y verificados (Pages + Fly, `/salud` devolviendo el SHA), pero seguir el documento a mano dejó fuera cinco ficheros.

Este documento recoge las diez fricciones y lo que se ha cambiado en la plantilla para eliminarlas.

## La corrección de fondo: `tools/inicializar.sh`

En vez de una lista de ficheros en prosa que hay que ir aplicando a mano, un script:

```
tools/inicializar.sh --nombre MiProyecto --owner miusuario \
                     --app-fly miproyecto-npi --drive-id 1AbC... [--prefijo MP]
```

- Sustituye los siete valores de la plantilla en los **doce** sitios afectados, en orden (compuestos antes que el slug suelto, para no corromper `desdemovil-npi` ni `desdemovil-backend`).
- Deriva el slug del paquete Rust y el usuario del contenedor del nombre del proyecto, y el prefijo de build de sus iniciales (`MiProyecto` → `MP-B1`).
- Regenera `README.md` entero, aparta `docs/planificacion/` heredado a `docs/plantilla/` y deja `docs/planificacion/` vacío para el proyecto nuevo.
- Termina haciendo `grep` de `PLANTILLA`, `DesdeMovil`, `desdemovil`, el id de Drive viejo y el prefijo viejo en todo el repo, y **sale con código 1 listando lo que falte**.

Probado desatendido sobre el árbol de esta misma plantilla con parámetros ficticios (`CasaVerde`): sin residuos y `cargo build --release` en verde con el paquete renombrado.

## Las diez fricciones

| # | Fricción | Corrección |
|---|---|---|
| 1 | La lista de ficheros del paso 1 omitía `app/Cargo.toml` y `app/Dockerfile` (con marcador) y `README.md`, `docs/index.html` y `app/src/main.rs` (**sin** marcador). Al hacerlo a mano queda el nombre viejo en el mock público y en la respuesta de `GET /`. | El script cubre los doce sitios; `ARRANQUE.md` los tabula y marca cuáles no llevan marcador. |
| 2 | `grep "PLANTILLA:"` no es un checklist fiable: la cadena aparece en prosa en `ARRANQUE.md` y en `plantilla.md`, y el "diez sitios" de `plantilla.md` no cuadra con su tabla de ocho. | El checklist lo hace el script, con exclusiones explícitas, y aborta si encuentra algo. |
| 3 | El prefijo de build `DM-B3` que exige `CLAUDE.md` viene de *DesdeMovil* y de una fase de este proyecto; nada decía qué usar en uno nuevo. | Derivado de las iniciales del nombre, forzable con `--prefijo`. |
| 4 | Nada decía qué hacer con `docs/planificacion/` heredado, que llega mezclado con la carpeta donde va la planificación del proyecto nuevo. | El script lo mueve a `docs/plantilla/`. |
| 5 | El error de Pages que documentaba (`Get Pages site failed… Not Found`) es solo un *warning*; el fallo real es `Create Pages site failed. Error: Resource not accessible by integration`. | `ARRANQUE.md` cita el error real y explica que `enablement: true` no sustituye al paso manual porque el `GITHUB_TOKEN` no puede crear el sitio. |
| 6 | *Use this template* dispara los dos workflows con el commit inicial y ambos fallan: el historial de Actions arranca en rojo sin aviso. | Avisado en un recuadro. |
| 7 | El nombre de app de Fly es único en **todo** Fly.io; si está cogido, `flyctl apps create \|\| true` lo traga y el fallo aparece después, en el `deploy`. | Advertencia añadida al paso 3. |
| 8 | Las sesiones de Code llegan atadas a una rama `claude/…`, pero solo `main` dispara los workflows: sin decirlo, la inicialización no se puede verificar. | El bloque a pegar dice "haz commit y push **a main**" y explica por qué. |
| 9 | Nada decía qué hacer con `ARRANQUE.md` en el repo hijo. | Se conserva, con un aviso al principio para quien lo abra en un repo ya inicializado. |
| 10 | "Actualiza también el id de Drive" sin decir dónde. | Lo hace el script; `ARRANQUE.md` dice que es solo `CLAUDE.md`. |

## Otros cambios

- `actions/checkout` sube a `v5` en los dos workflows: quita el aviso de deprecación de Node 20. `actions/configure-pages@v5` sigue avisando; no hay versión posterior.

## Limitación conocida

- **[SUPUESTO] `tools/*.ps1` sigue sin ejecutarse**: no hay `pwsh` en el sandbox de las sesiones. Plan B si algo falla: pasar `-Proyecto` y `-Root` explícitos.
