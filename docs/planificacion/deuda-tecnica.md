# Deuda técnica

Lo que queda pendiente a propósito, con el plan para hacerlo. Cada entrada dice por qué se aplazó y qué hay que tocar, para que una sesión futura la retome sin volver a investigar.

## DT-1 · Peripatéticos limpio: una copia sin el historial del desarrollo

**Estado:** pendiente (paso 2). El paso 1 se hizo el 27-09-2026: las páginas que ve el cliente ya no enlazan nada del desarrollo.

**Qué resuelve.** Un cliente no debe ver cómo se construyó Peripatéticos. Tras el paso 1 no hay enlaces, pero todo sigue a la vista para quien lo busque:

- La página de GitHub de cada app dice «generated from `npiobject-labs/DesdeMovil`» (el instalador hace `gh repo create --template npiobject-labs/DesdeMovil`), y ahí está el historial entero: commits, PR, `docs/planificacion/`, `docs/bitacora/`.
- `bitacora.html`, `mocks/`, las guías técnicas y `holamundo.html` siguen publicados en Pages y se abren escribiendo la dirección.

**Qué es el paso 2.** Un repositorio público nuevo, `npiobject-labs/peripateticos` ([SUPUESTO] el nombre; confirmarlo con el usuario antes de crearlo), marcado como *Template repository*, con:

- un solo commit por versión publicada, sin historial del desarrollo;
- la bitácora vacía, sin `docs/planificacion/`, sin mocks, sin guías técnicas ni `docs/plantilla/`;
- su web en `https://npiobject-labs.github.io/peripateticos/`: la dirección que se da a los clientes.

`DesdeMovil` sigue siendo el **taller**: aquí se desarrolla con Claude y aquí se escribe la bitácora. **No se desarrolla en la copia**: si se hiciera, su bitácora se volvería a llenar con el desarrollo.

**Cómo se publica una versión.** Un workflow `publicar-version.yml` en `DesdeMovil` (`workflow_dispatch`) que:

1. Arma el árbol limpio con una **lista blanca** de ficheros (`app/`, `.github/workflows/` necesarios, `docs/` de cara al cliente, `docs/bitacora/README.md` y `ejemplo.json`, `CLAUDE.md`, `ARRANQUE.md`, `README.md`, `tools/` salvo `*-V1.ps1`).
2. Sustituye `npiobject-labs/DesdeMovil` por `npiobject-labs/peripateticos` donde toque.
3. Hace un commit «Versión AAAAMMDD-NNN» en la copia, con un token con permiso de escritura solo en ese repositorio (secreto de la organización; [SUPUESTO] un fine-grained PAT o una GitHub App, a decidir).
4. Espera a que el Pages de la copia quede en `success`.

**Qué hay que cambiar.**

- `docs/instalador/peripateticos.ps1`: `$Plantilla` por defecto a `npiobject-labs/peripateticos` (ya admite `PERI_PLANTILLA` para probar antes).
- `docs/pc.html`: la descarga del programa sale de `raw.githubusercontent.com/npiobject-labs/DesdeMovil/main/docs/instalador/`; en la copia, de la suya.
- `.github/workflows/init-plantilla.yml`: las sustituciones que protegen `template_name=DesdeMovil` y `github.com/npiobject-labs/DesdeMovil`, la comprobación de residuos y el texto del aviso final.
- `<meta name="fly-app">` de `instalar.html` (la demo «Saluda»): app de Fly `peripateticos-npiobject-labs`, que crea `deploy.yml` en el primer push de la copia.
- `CLAUDE.md`, `ARRANQUE.md`, `README.md` y los textos con el nombre o las URL de `DesdeMovil`.
- A mano, en la copia: **Settings → Template repository** activado y **Settings → Pages → Source: GitHub Actions**.
- Las apps ya creadas (`prupru` y las demás) siguen apuntando a `DesdeMovil`: no hace falta tocarlas.

**Opcional, después.** Hacer privado `DesdeMovil`. [SUPUESTO] con el plan gratuito, un repositorio privado no publica Pages, así que el taller perdería su web de pruebas. Plan B: dejarlo público y sin enlaces, como tras el paso 1.

**Cómo se da por hecho.** Montar una app de prueba con el instalador apuntando a la copia y comprobar que su repositorio dice «generated from `npiobject-labs/peripateticos`», que la bitácora de la copia está vacía y que su menú funciona igual.

**Esfuerzo estimado:** una sesión.
