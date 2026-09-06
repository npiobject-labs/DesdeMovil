# Arranque

## Por proyecto (2 pasos)

1. **Crear el repo**: [Use this template](https://github.com/new?template_name=DesdeMovil&template_owner=npiobject).
2. **Pages**: en el repo nuevo, **Settings → Pages → Build and deployment → Source**: cambia el desplegable de **Deploy from a branch** a **GitHub Actions**.
   Si lo dejas como está tendrás un enlace que funciona pero que muestra el README en vez del mock; y si el workflow corre antes de este cambio, falla con `Create Pages site failed. Error: Resource not accessible by integration` (precedido de un *warning* `Get Pages site failed… Not Found`). El `enablement: true` de `configure-pages` **no** sustituye a este paso: el `GITHUB_TOKEN` no tiene permiso para crear el sitio.

> **El primer run en rojo es normal.** *Use this template* dispara `pages.yml` con el commit inicial, antes de que hayas tocado Settings, así que ese run falla. El historial de Actions arranca en rojo y no es un problema: `init-plantilla.yml` relanza Pages al terminar. (`deploy.yml` no: sin `FLY_API_TOKEN` termina en verde.)

Y ya. Abre una sesión en [claude.ai/code](https://claude.ai/code) con el repo seleccionado y pide:

```
verifica que el proyecto quedó inicializado y que Pages responde
```

No hay nada que rellenar. `.github/workflows/init-plantilla.yml` deja el repo entero con el nombre del proyecto:

| Qué | Dónde |
|---|---|
| Nombre y owner | `CLAUDE.md`, `README.md`, `ARRANQUE.md`, `docs/*.html`, `tools/*.ps1`, `app/src/main.rs` |
| Paquete del backend (`<slug>-backend`) | `app/Cargo.toml`, `app/Cargo.lock`, `app/Dockerfile` |
| Usuario del runtime | `app/Dockerfile` |
| Prefijo del `build` (iniciales: `CasaVerde` → `CV-B1`) | `CLAUDE.md`, `docs/index.html`, `docs/guia.html` |
| Sección **Parámetros** rellenada, id de Drive vaciado | `CLAUDE.md` |
| Documentación heredada apartada a `docs/plantilla/` | `docs/planificacion/` queda limpia, con su `README.md` |

Al final hace `grep` de todo lo que huela a plantilla fuera de `docs/plantilla/` y **falla el run si encuentra algo**: ese grep es el checklist real, no una lista de ficheros que revisar a mano. Después borra el marcador `.plantilla-pendiente`, se deshabilita a sí mismo y relanza `pages.yml`. Si al crear el repo no llegó a lanzarse, la sesión lo lanza desde **Actions → Inicializar plantilla → Run workflow**.

No se borra a sí mismo porque no puede: `GITHUB_TOKEN` no tiene permiso para modificar nada bajo `.github/workflows/`, y un commit que lo intente hace que GitHub **rechace el push entero**. Por eso el workflow no toca ningún fichero de ahí y se apaga por la API en su lugar. Queda en el repo, deshabilitado e inerte —sin el marcador no haría nada aunque se relanzara—; bórralo a mano si te molesta.

Resultado: https://npiobject.github.io/DesdeMovil/ sirviendo el mock de `docs/`.

## Si a mitad del proyecto necesitas Fly

1. Crea un token de organización en [fly.io/tokens](https://fly.io/tokens) (o `fly tokens create org`).
2. Guárdalo en el repo: **Settings → Secrets and variables → Actions → New repository secret**, nombre exacto **`FLY_API_TOKEN`**. No lo pegues en ningún fichero ni en el chat.
3. Opcional: define la variable (pestaña **Variables**) **`FLY_APP`** si quieres un nombre concreto. Sin ella, la app se llama `<repo>-<owner>` en minúsculas, recortado a 30 caracteres.

El **nombre de app es único en todo Fly.io**, no solo en tu cuenta. Si el que toca ya está cogido por otra cuenta, `flyctl apps create` no protesta —el workflow lo ignora con `|| true`— y el fallo aparece más tarde, en el paso de `deploy`, con un mensaje que no apunta a la causa. El nombre derivado lleva el owner de sufijo justamente para que eso no pase; si aun así choca, define `FLY_APP`.

A partir de ahí, el siguiente push que toque `app/**` despliega; o lánzalo a mano desde **Actions → Desplegar backend en Fly.io → Run workflow**. El primer despliegue crea la app y tarda varios minutos porque compila Rust.

Queda `https://<APP>.fly.dev/` (texto plano) y `https://<APP>.fly.dev/salud` devolviendo `{"ok":true,"build":"<SHA>"}`. La verificación no la haces tú: el propio workflow hace `curl` a `/salud` y falla el run si la respuesta no contiene el SHA del commit desplegado.

Sin secreto, `deploy.yml` termina en verde con el aviso "Fly no configurado" y no despliega nada.

## Si quieres copias en Drive

Crea una carpeta normal en **Mi unidad** (no un "Proyecto" de Drive: el conector no puede escribir en esos), ábrela y copia el id de la URL `https://drive.google.com/drive/folders/<ID>`. Pégalo en la fila **Carpeta de Drive (id)** de la sección **Parámetros** de `CLAUDE.md`. Con la fila vacía, Drive se omite sin más.

## Aterrizar en el PC

En PowerShell:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/npiobject/DesdeMovil/main/tools/aterrizar.ps1)))
```

Crea `%USERPROFILE%\C - Desarrollo\DesdeMovil\repo` con un clon de `main`. Es idempotente y **sobrescribe** la copia local sin preguntar (`reset --hard` + `clean -fdx`): el PC es un espejo de solo lectura. Para saber si estás al día, `tools\estado.ps1`.

---

Guía extendida: [`docs/guia.html`](docs/guia.html) · Reglas para los agentes: [`CLAUDE.md`](CLAUDE.md)
