#!/usr/bin/env bash
# Inicializa un repo recien creado desde la plantilla: sustituye el nombre del
# proyecto, el owner, la app de Fly, el id de Drive y el prefijo de build en
# TODOS los sitios donde aparecen, aparta la documentacion heredada y verifica
# que no queda ningun residuo.
#
# Uso:
#   tools/inicializar.sh --nombre MiProyecto --owner miusuario \
#                        --app-fly miproyecto-npi --drive-id 1AbC... [--prefijo MP]
#
# Correr desde la raiz del repo. Si la verificacion final falla, el script sale
# con codigo 1 y lista lo que ha quedado sin sustituir.
set -euo pipefail

# --- Valores de la plantilla (lo que hay que sustituir) ---
P_NOMBRE='DesdeMovil'
P_OWNER='npiobject'
P_APP='desdemovil-npi'
P_SLUG='desdemovil'
P_DRIVE='1-0wWhp_-rrSgxKrr0AN34dg_Y2nAPK2J'
P_PREFIJO='DM-B3'

NOMBRE=''; OWNER=''; APP=''; DRIVE=''; PREFIJO=''
while [ $# -gt 0 ]; do
  case "$1" in
    --nombre)   NOMBRE="$2"; shift 2 ;;
    --owner)    OWNER="$2";  shift 2 ;;
    --app-fly)  APP="$2";    shift 2 ;;
    --drive-id) DRIVE="$2";  shift 2 ;;
    --prefijo)  PREFIJO="$2"; shift 2 ;;
    -h|--help)  sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Opcion desconocida: $1" >&2; exit 2 ;;
  esac
done

for v in NOMBRE OWNER APP DRIVE; do
  if [ -z "${!v}" ]; then
    echo "Falta --$(echo "$v" | tr 'A-Z_' 'a-z-'). Usa --help." >&2; exit 2
  fi
done

[ -f ARRANQUE.md ] && [ -d app ] || { echo "Ejecuta desde la raiz del repo." >&2; exit 2; }

# Slug para el paquete Rust y el usuario del contenedor.
SLUG="$(printf '%s' "$NOMBRE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
[ -n "$SLUG" ] || { echo "El nombre no produce un slug valido." >&2; exit 2; }

# Prefijo de build: por defecto, las iniciales mayusculas del nombre.
if [ -z "$PREFIJO" ]; then
  PREFIJO="$(printf '%s' "$NOMBRE" | grep -o '[A-Z]' | tr -d '\n' || true)"
  [ -n "$PREFIJO" ] || PREFIJO="$(printf '%s' "$NOMBRE" | cut -c1-2 | tr '[:lower:]' '[:upper:]')"
fi
PREFIJO="${PREFIJO}-B1"

# --- Ficheros con algun valor de la plantilla (README.md se regenera aparte) ---
FICHEROS="
CLAUDE.md
.github/workflows/deploy.yml
.github/workflows/pages.yml
app/fly.toml
app/Cargo.toml
app/Cargo.lock
app/Dockerfile
app/src/main.rs
docs/index.html
tools/aterrizar.ps1
tools/estado.ps1
"

esc() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }

for f in $FICHEROS; do
  [ -f "$f" ] || { echo "AVISO: no existe $f, se salta." >&2; continue; }
  # El orden importa: primero los compuestos, luego el slug suelto.
  sed -i \
    -e "s|$(esc "$P_APP")|$(esc "$APP")|g" \
    -e "s|$(esc "$P_SLUG")-backend|$(esc "$SLUG")-backend|g" \
    -e "s|$(esc "$P_DRIVE")|$(esc "$DRIVE")|g" \
    -e "s|$(esc "$P_PREFIJO")|$(esc "$PREFIJO")|g" \
    -e "s|$(esc "$P_NOMBRE")|$(esc "$NOMBRE")|g" \
    -e "s|$(esc "$P_SLUG")|$(esc "$SLUG")|g" \
    -e "s|$(esc "$P_OWNER")|$(esc "$OWNER")|g" \
    "$f"
done

# --- Marcadores PLANTILLA ---
# Bloque HTML multilinea de CLAUDE.md: fuera entero.
sed -i '/<!-- PLANTILLA:/,/-->/d' CLAUDE.md
# Lineas que son solo instruccion de plantilla: fuera.
sed -i '/^# PLANTILLA: este workflow no lleva/d' .github/workflows/pages.yml
sed -i '/^  # PLANTILLA: cambia est/d' tools/aterrizar.ps1 tools/estado.ps1
sed -i '/^# app\/Dockerfile (COPY --from=builder/d' app/Cargo.toml
# El resto conserva la explicacion util; solo se le quita el prefijo.
sed -i 's/# PLANTILLA: /# /' \
  .github/workflows/deploy.yml app/fly.toml app/Cargo.toml app/Dockerfile
sed -i 's|^# si cambias este nombre.*|# Si cambias este nombre, cambia tambien la ruta del binario en app/Dockerfile.|I' app/Cargo.toml
# Compacta el hueco que deja el bloque borrado al principio de CLAUDE.md.
sed -i '/./,/^$/!d' CLAUDE.md

# --- Documentacion heredada de la plantilla ---
# docs/planificacion/ es para la planificacion de ESTE proyecto; lo que viene de
# la plantilla se aparta a docs/plantilla/ para no mezclarlo.
mkdir -p docs/plantilla
for d in docs/planificacion/*.md docs/planificacion/sesiones; do
  [ -e "$d" ] || continue
  mv "$d" docs/plantilla/
done
mkdir -p docs/planificacion/sesiones
touch docs/planificacion/sesiones/.gitkeep

# --- README del proyecto ---
{
  printf '# %s\n\n' "$NOMBRE"
  printf 'Proyecto creado desde la plantilla del flujo "PC arranca, movil continua": mock\n'
  printf 'estatico en GitHub Pages y backend en Fly.io, ambos desplegados y verificados\n'
  printf 'por workflows desde sesiones en la nube.\n\n'
  printf -- '- Mock (Pages): https://%s.github.io/%s/\n' "$OWNER" "$NOMBRE"
  printf -- '- Backend (Fly): https://%s.fly.dev/ y https://%s.fly.dev/salud\n' "$APP" "$APP"
  printf -- '- Reglas de trabajo para los agentes: [CLAUDE.md](CLAUDE.md)\n'
  printf -- '- Planificacion y resultados por fase: [docs/planificacion/](docs/planificacion/)\n'
  printf -- '- Como se arranca un proyecto desde esta plantilla: [ARRANQUE.md](ARRANQUE.md)\n'
  printf -- '- Historial de la plantilla de origen: [docs/plantilla/](docs/plantilla/)\n'
} > README.md

# --- Verificacion: no puede quedar ningun residuo fuera de la plantilla ---
EXCL="--exclude-dir=.git --exclude-dir=plantilla --exclude=ARRANQUE.md --exclude=inicializar.sh"
residuos="$(grep -rnI $EXCL -e 'PLANTILLA' -e "$P_NOMBRE" -e "$P_SLUG" -e "$P_DRIVE" -e "$P_PREFIJO" . || true)"
if [ -n "$residuos" ]; then
  echo "ERROR: quedan residuos de la plantilla:" >&2
  printf '%s\n' "$residuos" >&2
  exit 1
fi

echo "Inicializado."
echo "  Proyecto : $NOMBRE ($OWNER/$NOMBRE)"
echo "  Fly      : $APP"
echo "  Paquete  : $SLUG-backend"
echo "  Drive    : $DRIVE"
echo "  Build    : $PREFIJO-AAAAMMDD-NNN"
echo
echo "Siguiente: revisa 'git diff', haz commit y 'git push origin main' (los dos"
echo "workflows solo se disparan en main), y verifica los runs por la API de Actions."
