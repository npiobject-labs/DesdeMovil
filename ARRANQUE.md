# Arranque de un proyecto nuevo desde esta plantilla

## 1. Lo que tienes que hacer tú (ningún agente puede)

1. **Crear el repo.** En GitHub, botón **Use this template → Create a new repository**. Anota `owner/repo`.
2. **Activar Pages.** En el repo nuevo: **Settings → Pages → Build and deployment → Source: GitHub Actions**. Sin esto el primer despliegue falla con `Get Pages site failed… Not Found`.
3. **Token de Fly.io.** En https://fly.io/dashboard → **Tokens → Create token** (o `fly tokens create deploy`). Copia el valor y guárdalo en el repo en **Settings → Secrets and variables → Actions → New repository secret**, con nombre exacto **`FLY_API_TOKEN`**. No lo pegues en ningún fichero ni en el chat.
4. **Carpeta de Drive.** En **Mi unidad** crea una carpeta normal con el nombre del proyecto (no un "Proyecto" de Drive: el conector no puede escribir en esos). Ábrela y copia el id de la URL: `https://drive.google.com/drive/folders/<ID>`.

## 2. Primera instrucción para la sesión de Code

Abre claude.ai/code con el repo nuevo seleccionado y pega esto, rellenando los cuatro valores:

```
Inicializa este proyecto desde la plantilla.

- Nombre del proyecto: <NOMBRE>
- Owner de GitHub: <OWNER>
- App de Fly.io: <APP-FLY>
- Carpeta de Drive (id): <ID-DRIVE>

1. Busca "PLANTILLA:" en todo el repo y sustituye en cada sitio el nombre del
   proyecto, el owner y el nombre de la app de Fly por los valores de arriba:
   app/fly.toml, .github/workflows/deploy.yml, CLAUDE.md, tools/aterrizar.ps1 y
   tools/estado.ps1. Actualiza también el id de Drive y las dos URLs vivas de
   CLAUDE.md. Borra los comentarios PLANTILLA que queden ya resueltos.
2. Haz push a main.
3. Verifica por la API de GitHub Actions que los dos workflows (pages.yml y
   deploy.yml) terminan en success para ese SHA. No me avises hasta tenerlos en
   verde; si alguno falla, lee los logs, diagnostica y corrige.
4. Dime al final: SHA, URL de Pages, URL de Fly y el JSON que devuelve /salud.
```

## 3. Qué deberías ver al terminar

- `https://<OWNER>.github.io/<NOMBRE>/` sirviendo el mock de `docs/`.
- `https://<APP-FLY>.fly.dev/` devolviendo texto plano y `/salud` devolviendo `{"ok":true,"build":"<SHA>"}` con el SHA de ese despliegue.

Si algo no responde, el diagnóstico está siempre en el log del run, no en la sesión: el sandbox no alcanza ni Pages ni Fly.
