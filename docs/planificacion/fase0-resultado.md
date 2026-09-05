# DesdeMovil — Fase 0: resultado

**Fecha:** 2026-09-05
**Repositorio:** https://github.com/npiobject/DesdeMovil
**Rama:** main

## Qué se ha hecho

- `docs/index.html` — mock mínimo con `<meta name="build" content="DM-B3-20260905-001">` y título "DesdeMovil · mock 0".
- `.github/workflows/pages.yml` — despliegue de `docs/` a GitHub Pages con
  `actions/configure-pages@v5` + `actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`,
  permisos `contents: read`, `pages: write`, `id-token: write`, disparo en `push` a `main` y `workflow_dispatch`.

## Commits

| SHA | Descripción |
|---|---|
| `82c817e` | Mock `docs/index.html` + workflow de Pages |
| `1810265` | `configure-pages` con `enablement: true` (intento de auto-habilitar Pages) |

## Estado del workflow

| Run | SHA | Resultado | Causa |
|---|---|---|---|
| [#1](https://github.com/npiobject/DesdeMovil/actions/runs/33987990711) | `82c817e` | ❌ failure | `Get Pages site failed ... Not Found` — Pages no está habilitado en el repo |
| [#2](https://github.com/npiobject/DesdeMovil/actions/runs/33988024125) | `1810265` | ❌ failure | `Create Pages site failed. Resource not accessible by integration` — el `GITHUB_TOKEN` del workflow no tiene permiso para crear el sitio |

**Conclusión:** el YAML es correcto; el bloqueo es de configuración del repositorio, no de código.

## URL de Pages (prevista, aún no publicada)

https://npiobject.github.io/DesdeMovil/

## Acción manual pendiente (única)

En **Settings → Pages** del repositorio `npiobject/DesdeMovil`:

1. **Build and deployment → Source**: seleccionar **GitHub Actions** (no "Deploy from a branch").
2. Guardar.
3. Volver a lanzar el workflow: **Actions → "Deploy docs to GitHub Pages" → Run workflow** (rama `main`),
   o hacer cualquier push a `main`.

Opcionalmente, si el fallo persistiera por permisos del token:
**Settings → Actions → General → Workflow permissions** → "Read and write permissions".

Una vez habilitado, `enablement: true` deja de ser necesario pero es inocuo (el sitio ya existirá).

## Verificación posterior

Con Pages ya activo, comprobar en la respuesta de `GET /repos/npiobject/DesdeMovil/pages`
que `status: built` y que el HTML servido contiene `DM-B3-20260905-001`.
