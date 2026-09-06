# Arranque de un proyecto nuevo desde esta plantilla

> Si estás leyendo esto en un repo **ya inicializado** (existe `docs/plantilla/`),
> este fichero es solo el registro de cómo se creó: no hay nada que ejecutar.

## 1. Lo que tienes que hacer tú (ningún agente puede)

1. **Crear el repo.** En GitHub, botón **Use this template → Create a new repository**. Anota `owner/repo`.
2. **Activar Pages.** En el repo nuevo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
   Sin esto el primer despliegue falla con `Create Pages site failed. Error: Resource not accessible by integration`
   (precedido de un *warning* `Get Pages site failed… Not Found`). El `enablement: true` que lleva
   `configure-pages` en el workflow **no** sustituye a este paso: el `GITHUB_TOKEN` no tiene permiso para crear el sitio.
3. **Token de Fly.io.** En https://fly.io/dashboard → **Tokens → Create token** (o `fly tokens create deploy`). Copia el valor y guárdalo en el repo en **Settings → Secrets and variables → Actions → New repository secret**, con nombre exacto **`FLY_API_TOKEN`**. No lo pegues en ningún fichero ni en el chat.
   El **nombre de la app de Fly es único en todo Fly.io**, no solo en tu cuenta: elige uno con sufijo propio (`<proyecto>-npi`). Si está cogido por otra cuenta, `flyctl apps create` no protesta —el workflow lo ignora con `|| true`— y el fallo aparece más tarde, en el paso de `deploy`, con un mensaje que no apunta a la causa.
4. **Carpeta de Drive.** En **Mi unidad** crea una carpeta normal con el nombre del proyecto (no un "Proyecto" de Drive: el conector no puede escribir en esos). Ábrela y copia el id de la URL: `https://drive.google.com/drive/folders/<ID>`.

> **Los dos runs rojos del principio son normales.** *Use this template* dispara `pages.yml` y `deploy.yml` con el commit inicial, antes de que hayas hecho los pasos 2 y 3, así que ambos fallan. El historial de Actions arranca en rojo; no es un problema.

## 2. Primera instrucción para la sesión de Code

Abre claude.ai/code con el repo nuevo seleccionado y pega esto, rellenando los cuatro valores:

```
Inicializa este proyecto desde la plantilla. Lee ARRANQUE.md y CLAUDE.md y síguelos.

- Nombre del proyecto: <NOMBRE>
- Owner de GitHub: <OWNER>
- App de Fly.io: <APP-FLY>
- Carpeta de Drive (id): <ID-DRIVE>

1. Ejecuta:
   tools/inicializar.sh --nombre <NOMBRE> --owner <OWNER> \
                        --app-fly <APP-FLY> --drive-id <ID-DRIVE>
   El script sustituye los valores en todos los sitios, aparta la documentación
   heredada a docs/plantilla/ y falla si queda cualquier residuo. Revisa el diff.
2. Haz commit y push **a main**: los dos workflows solo se disparan en esa rama,
   así que sin esto no hay nada que verificar.
3. Verifica por la API de GitHub Actions que los dos workflows (pages.yml y
   deploy.yml) terminan en success para ese SHA. No me avises hasta tenerlos en
   verde; si alguno falla, lee los logs, diagnostica y corrige.
4. Dime al final: SHA, URL de Pages, URL de Fly y el JSON que devuelve /salud.
```

## 3. Qué hace `tools/inicializar.sh`

Sustituye, en este orden, `desdemovil-npi` → app de Fly, `desdemovil-backend` → `<slug>-backend`,
el id de Drive, el prefijo de build, `DesdeMovil` → nombre, `desdemovil` → slug y `npiobject` → owner.
Estos son **todos** los sitios afectados; los cinco últimos no llevan marcador `PLANTILLA:` y son los
que se olvidan al hacerlo a mano:

| Fichero | Qué cambia | ¿Marcador? |
|---|---|---|
| `app/fly.toml` | `app` (nombre en Fly) | sí |
| `.github/workflows/deploy.yml` | `FLY_APP` | sí |
| `app/Cargo.toml` + `app/Cargo.lock` | `name` del paquete | sí (solo el `.toml`) |
| `app/Dockerfile` | ruta del binario y usuario del runtime | sí |
| `.github/workflows/pages.yml` | nada; solo se limpia el comentario | sí |
| `CLAUDE.md` | nombre, owner, app de Fly, **id de Drive**, prefijo de build y las dos URLs vivas | sí |
| `tools/aterrizar.ps1` | `-Proyecto` y `-Owner` por defecto | sí |
| `tools/estado.ps1` | `-Proyecto` por defecto | sí |
| `README.md` | se regenera entero con el nombre y las URLs | **no** |
| `docs/index.html` | título, `h1` y el prefijo del `meta name="build"` | **no** |
| `app/src/main.rs` | texto de `GET /` y del log de arranque | **no** |
| `docs/planificacion/*` | se aparta a `docs/plantilla/` | **no** |

El **id de Drive** aparece en un solo sitio: `CLAUDE.md`.

El **prefijo del número de build** se deriva de las iniciales del nombre: `MiProyecto` → `MP-B1`, de modo
que el mock queda en `MP-B1-AAAAMMDD-NNN`. Se puede forzar con `--prefijo`.

Al final, el script hace `grep` de `PLANTILLA`, `DesdeMovil`, `desdemovil`, el id de Drive viejo y el
prefijo viejo en todo el repo (excluyendo `docs/plantilla/`, este fichero y el propio script) y **sale con
error si encuentra algo**. Esa verificación es el checklist real; `grep -rn "PLANTILLA:"` a mano no sirve,
porque la cadena también aparece en prosa en este fichero y en `docs/plantilla/plantilla.md`.

## 4. Qué deberías ver al terminar

- `https://<OWNER>.github.io/<NOMBRE>/` sirviendo el mock de `docs/`.
- `https://<APP-FLY>.fly.dev/` devolviendo texto plano y `/salud` devolviendo `{"ok":true,"build":"<SHA>"}` con el SHA de ese despliegue.

Si algo no responde, el diagnóstico está siempre en el log del run, no en la sesión: el sandbox no alcanza ni Pages ni Fly.
