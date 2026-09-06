# Arranque

## Por proyecto (2 pasos)

1. **Crear el repo**: [Use this template](https://github.com/new?template_name=DesdeMovil&template_owner=npiobject).
2. **Pages**: en el repo nuevo, **Settings → Pages → Build and deployment → Source**: cambia el desplegable de **Deploy from a branch** a **GitHub Actions**.
   Si lo dejas como está tendrás un enlace que funciona pero que muestra el README en vez del mock.

Y ya. Abre una sesión en [claude.ai/code](https://claude.ai/code) con el repo seleccionado y pide:

```
verifica que el proyecto quedó inicializado y que Pages responde
```

No hay nada que rellenar: `.github/workflows/init-plantilla.yml` sustituye solo el nombre y el owner en `CLAUDE.md`, `README.md`, `ARRANQUE.md`, `tools/*.ps1` y `docs/*.html`, rellena la sección **Parámetros** de `CLAUDE.md`, borra el marcador `.plantilla-pendiente` y se borra a sí mismo. Si al crear el repo no llegó a lanzarse, la sesión lo lanza a mano desde **Actions → Inicializar plantilla → Run workflow**.

Resultado: https://npiobject.github.io/DesdeMovil/ sirviendo el mock de `docs/`.

## Si a mitad del proyecto necesitas Fly

1. Crea un token de organización en [fly.io/tokens](https://fly.io/tokens) (o `fly tokens create org`).
2. Guárdalo en el repo: **Settings → Secrets and variables → Actions → New repository secret**, nombre exacto **`FLY_API_TOKEN`**. No lo pegues en ningún fichero ni en el chat.
3. Opcional: define la variable (pestaña **Variables**) **`FLY_APP`** si quieres un nombre concreto. Sin ella, la app se llama `<repo>-<owner>` en minúsculas, recortado a 30 caracteres.

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
