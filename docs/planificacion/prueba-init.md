# Primera ejecución real de `init-plantilla.yml`

**Fecha:** 2026-09-06
**Repo de prueba:** [`npiobject/PruebaInit`](https://github.com/npiobject/PruebaInit), público, creado con *Use this template*.
**Motivo:** hasta ahora el workflow solo se había ensayado en el sandbox, extrayendo sus `run:` sobre copias del árbol. En la plantilla no puede correr (la barrera `is_template == false` corta el job), así que la única prueba posible era un repo generado de verdad.

Encontró un fallo que ningún ensayo en sandbox podía encontrar, porque no es del script: es de los permisos del token con el que corre.

## Fallo: el push del commit de inicialización, rechazado

Run [34038649858](https://github.com/npiobject/PruebaInit/actions/runs/34038649858), commit inicial `337281f`. Los siete primeros pasos en verde —sustitución, documentación heredada apartada y **el paso antirresiduos incluido**— y el octavo:

```
[main 3656bc9] Inicializar la plantilla para npiobject/PruebaInit
 28 files changed, 43 insertions(+), 248 deletions(-)
 delete mode 100644 .github/workflows/init-plantilla.yml
 delete mode 100644 .plantilla-pendiente
 ...
 ! [remote rejected] HEAD -> main (refusing to allow a GitHub App to create or
   update workflow `.github/workflows/pages.yml` without `workflows` permission)
```

**`GITHUB_TOKEN` no puede crear ni modificar nada bajo `.github/workflows/`**, y no es algo que se arregle con `permissions:`: no existe una clave `workflows` para ese token (sí existe el scope `workflow`, pero solo para PAT y GitHub Apps). Si el commit toca un solo fichero de esa carpeta, GitHub **rechaza el push entero** — no solo ese fichero. El commit hacía dos cosas ahí:

1. `sed -i '/^# PLANTILLA:/d' .github/workflows/pages.yml`, para quitar un comentario de una línea;
2. `rm -f .github/workflows/init-plantilla.yml`, la autodestrucción del propio workflow.

Resultado: **el trabajo entero se perdía**. El repo se quedaba exactamente como salió de la plantilla, con el marcador puesto y el nombre de `DesdeMovil` por todas partes, y el único aviso era un run en rojo.

### Corrección

- **`pages.yml` deja de llevar marcador `PLANTILLA:`.** Su comentario se reescribe en la plantilla (`# Este workflow no lleva el nombre del proyecto: init-plantilla.yml no lo toca.`), así que ya no hay nada que editar ahí en la inicialización. Era un comentario que solo decía «aquí no hay nada que sustituir»; costaba el push entero.
- **El workflow no se borra a sí mismo.** No puede. Se **deshabilita por la API** con `gh workflow disable init-plantilla.yml`, que solo necesita el `actions: write` que ya tenía. El marcador `.plantilla-pendiente` —que sí se borra, y no está bajo `.github/`— ya lo dejaba inerte; deshabilitarlo evita además un run vacío en cada push.
- **El grep antirresiduos excluye `init-plantilla.yml`**, que ahora sobrevive en el repo generado y contiene, por fuerza, las cadenas que busca. Es la herramienta, no el resultado.

Tras la corrección, el commit de inicialización **no toca ningún fichero de `.github/workflows/`**; comprobado en el sandbox con un `diff -rq` de esa carpeta antes y después: idénticas.

## Verificación tras la corrección

Run [34038895372](https://github.com/npiobject/PruebaInit/actions/runs/34038895372) — **success**. Commit resultante `f209929`, "Inicializar la plantilla para npiobject/PruebaInit". Lo comprobado en el árbol publicado, no en una copia local:

| Qué | Esperado | En el repo |
|---|---|---|
| Paquete Rust | `pruebainit-backend` | `Cargo.toml`, `Cargo.lock` y `Dockerfile`, los tres |
| Usuario del runtime | `pruebainit` | `useradd … pruebainit` + `USER pruebainit` |
| `GET /` y log | `PruebaInit backend` | `app/src/main.rs`, las dos cadenas |
| Prefijo del `build` | `PI-B1` | `docs/index.html` (`PI-B1-20260905-001`) y la regla de `CLAUDE.md` |
| Título y `h1` del mock | `PruebaInit · mock 0` | `docs/index.html` |
| Sección **Parámetros** | rellenada, Drive vacío | `PruebaInit` / `npiobject` / `derivada` / *(vacío)* |
| Documentación heredada | en `docs/plantilla/` | los 7 documentos + `sesiones/` |
| `docs/planificacion/` | limpia, con índice | `README.md` + `sesiones/` vacía |
| Marcador | borrado | no existe |
| `init-plantilla.yml` | deshabilitado | estado `disabled_manually` por la API |

Rastros de la plantilla que quedan, los tres queridos: el enlace *Use this template* de `ARRANQUE.md` (protegido a propósito), la cita de origen del `README.md` generado y el propio `init-plantilla.yml`.

Y el ciclo se cierra solo: `pages.yml` corrió por `workflow_dispatch` sobre el commit del bot ([34038902703](https://github.com/npiobject/PruebaInit/actions/runs/34038902703), **success**), que es el paso que existe precisamente porque un commit hecho con `GITHUB_TOKEN` no dispara workflows por push. Eso sí se confirma: el commit `f209929` no generó ningún run por `push`.

## Un supuesto que era falso

`simplificacion.md`, punto 5 de «Decisiones que no venían especificadas», daba por **[SUPUESTO]** que *crear un repo desde una plantilla no dispara workflows por push*. **Es falso.** El commit inicial `337281f` de `PruebaInit` disparó los tres workflows a la vez, todos con `event: push` y `run_number: 1`:

| Workflow | Run | Resultado |
|---|---|---|
| `init-plantilla.yml` | [34038649858](https://github.com/npiobject/PruebaInit/actions/runs/34038649858) | failure (el push rechazado de arriba) |
| `pages.yml` | [34038649877](https://github.com/npiobject/PruebaInit/actions/runs/34038649877) | failure en `Configure Pages`, Pages sin activar aún |
| `deploy.yml` | [34038649874](https://github.com/npiobject/PruebaInit/actions/runs/34038649874) | **success**, por la vía «Fly no configurado» |

Consecuencias, todas buenas menos la primera:

- El `workflow_dispatch` de `init-plantilla.yml` y la frase de `ARRANQUE.md` («si al crear el repo no llegó a lanzarse, la sesión lo lanza desde Actions») pasan de ser el camino esperado a ser una red de seguridad que normalmente no hace falta. Se quedan: no estorban.
- El aviso de `ARRANQUE.md` de que **el primer run sale en rojo** queda confirmado, y con el matiz exacto que dice: cae `pages.yml` —falla en `Configure Pages`, no en el despliegue— mientras `deploy.yml` termina en verde sin token. Un solo run rojo, no dos.

## Limitación de esta prueba

La corrección no se probó sobre un repo recién generado, sino llevando los dos workflows corregidos a `PruebaInit` y dejando que el push disparara la inicialización con el marcador todavía puesto. Lo que falló era el token con el que corre el workflow, y eso es idéntico en los dos casos: el run corrió como `GITHUB_TOKEN` y su push pasó. **[SUPUESTO]** que un repo generado de cero se comporta igual; plan B para confirmarlo: crear otro repo desde la plantilla, que ahora ya sale bien a la primera.
