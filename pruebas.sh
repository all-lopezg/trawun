#!/usr/bin/env bash
#
# Pruebas de Trawün.
#
# Corre sobre carpetas temporales: nunca toca tu proyecto ni tu carpeta de usuario.
# Uso: bash pruebas.sh
#
set -u

TRAWUN="$(cd "$(dirname "$0")" && pwd)/trawun.sh"
BASE="$(mktemp -d)"
FALLOS=0

VERDE=""; ROJO=""; FIN=""
if [ -t 1 ]; then
    VERDE=$'\033[32m'; ROJO=$'\033[31m'; FIN=$'\033[0m'
fi

comprobar() {
    # $1 = descripción, $2 = 0 si pasó
    if [ "$2" = "0" ]; then
        printf '  %s✓%s %s\n' "$VERDE" "$FIN" "$1"
    else
        printf '  %s✗%s %s\n' "$ROJO" "$FIN" "$1"
        FALLOS=$((FALLOS + 1))
    fi
}

existe()    { [ -e "$1" ]; comprobar "$2" "$?"; }
no_existe() { [ ! -e "$1" ]; comprobar "$2" "$?"; }
titulo()    { printf '\n%s\n' "$1"; }

# Corre trawun sin que la detección de asistentes dependa de esta máquina:
# HOME apunta a una carpeta vacía, así que no "ve" ningún asistente instalado.
hogar_limpio() {
    mkdir -p "$BASE/hogar"
    HOME="$BASE/hogar" bash "$TRAWUN" "$@"
}

# ---------------------------------------------------------------------------
titulo "1. Proyecto completo (reglas, skills, comandos y .mcp.json)"
P="$BASE/completo"
mkdir -p "$P/.claude/skills/api-docs" "$P/.claude/commands"
printf '# Reglas\n' > "$P/CLAUDE.md"
printf -- '---\nname: api-docs\ndescription: Prueba.\n---\n' > "$P/.claude/skills/api-docs/SKILL.md"
printf 'x\n' > "$P/.claude/commands/deploy.md"
printf '{}\n' > "$P/.mcp.json"
( cd "$P" && git init -q . && git add -A && git commit -qm inicial )
( cd "$P" && hogar_limpio -y --asistentes qoder . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe    "$P/AGENTS.md" "las reglas quedaron en AGENTS.md"
existe    "$P/.agents/skills/api-docs/SKILL.md" "el skill se movió a .agents/skills"
existe    "$P/.qoder/skills/api-docs/SKILL.md" "Qoder ve el skill por el enlace"
no_existe "$P/CLAUDE.md" "CLAUDE.md ya no está"
no_existe "$P/.claude" "no quedó .claude/"
existe    "$P/.mcp.json" ".mcp.json se conservó (Qoder lo lee)"
existe    "$P/.agentes-respaldo" "hay respaldo de lo que se movió"

titulo "2. Idempotencia (correrlo dos veces)"
( cd "$P" && hogar_limpio -y --asistentes qoder . ) >/dev/null 2>&1
comprobar "la segunda corrida también sale 0" "$?"
existe "$P/.agents/skills/api-docs/SKILL.md" "no duplicó ni rompió nada"

titulo "3. .claude/ sin carpeta de skills"
P="$BASE/sin-skills"
mkdir -p "$P/.claude/commands"
printf '# Reglas\n' > "$P/CLAUDE.md"
printf 'x\n' > "$P/.claude/commands/deploy.md"
( cd "$P" && hogar_limpio -y . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
no_existe "$P/.claude" ".claude/ se fue al respaldo"
existe "$P/.agentes-respaldo" "el comando propio quedó respaldado"

titulo "4. Proyecto vacío (modo sembrar)"
P="$BASE/vacio"
mkdir -p "$P"
printf 'x\n' > "$P/README.md"
( cd "$P" && hogar_limpio -y --asistentes qoder . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe "$P/AGENTS.md" "creó un AGENTS.md para completar"
existe "$P/.agents/skills" "creó .agents/skills"
existe "$P/.qoder/skills" "creó .qoder/skills"

titulo "5. Simulación (--dry-run) no toca nada"
P="$BASE/simular"
mkdir -p "$P"
printf '# Reglas\n' > "$P/CLAUDE.md"
( cd "$P" && hogar_limpio -n . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe    "$P/CLAUDE.md" "CLAUDE.md sigue igual"
no_existe "$P/AGENTS.md" "no creó AGENTS.md"
no_existe "$P/.agentes-respaldo" "no creó respaldo"

titulo "6. Sin terminal y sin --si: se niega a adivinar"
P="$BASE/sin-terminal"
mkdir -p "$P"
printf '# Reglas\n' > "$P/CLAUDE.md"
( cd "$P" && hogar_limpio . </dev/null ) >/dev/null 2>&1
codigo=$?
comprobar "sale con código 2" "$( [ "$codigo" = "2" ] && echo 0 || echo 1 )"
existe    "$P/CLAUDE.md" "no tocó CLAUDE.md"
no_existe "$P/AGENTS.md" "no creó AGENTS.md"

titulo "7. Qoder es opcional"
P="$BASE/sin-enlaces"
mkdir -p "$P/.claude/skills/api-docs"
printf '# Reglas\n' > "$P/CLAUDE.md"
printf -- '---\nname: api-docs\n---\n' > "$P/.claude/skills/api-docs/SKILL.md"
( cd "$P" && hogar_limpio -y --sin-enlaces . ) >/dev/null 2>&1
comprobar "sin --asistentes sale 0" "$?"
existe    "$P/.agents/skills/api-docs/SKILL.md" "los skills sí se movieron"
no_existe "$P/.qoder" "no creó .qoder/ (--sin-enlaces)"
no_existe "$P/.github/skills" "tampoco creó .github/skills"

titulo "8. Detección: sin asistentes instalados no crea enlaces"
P="$BASE/deteccion"
mkdir -p "$P/.claude/skills/api-docs"
printf -- '---\nname: api-docs\n---\n' > "$P/.claude/skills/api-docs/SKILL.md"
( cd "$P" && hogar_limpio -y . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
no_existe "$P/.qoder" "no inventó enlaces de Qoder"
existe    "$P/.agents/skills/api-docs/SKILL.md" "los skills quedaron en su sitio neutral"

titulo "9. Copilot como asistente elegido"
P="$BASE/copilot"
mkdir -p "$P/.claude/skills/api-docs"
printf -- '---\nname: api-docs\n---\n' > "$P/.claude/skills/api-docs/SKILL.md"
( cd "$P" && hogar_limpio -y --asistentes copilot . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe    "$P/.github/skills/api-docs/SKILL.md" "creó el enlace de Copilot"
no_existe "$P/.qoder" "no creó el de Qoder"

titulo "10. Lista de asistentes: varios y errores"
P="$BASE/varios"
mkdir -p "$P/.claude/skills/api-docs"
printf -- '---\nname: api-docs\n---\n' > "$P/.claude/skills/api-docs/SKILL.md"
( cd "$P" && hogar_limpio -y --asistentes qoder,copilot . ) >/dev/null 2>&1
comprobar "acepta lista separada por comas" "$?"
existe "$P/.qoder/skills/api-docs/SKILL.md" "creó el de Qoder"
existe "$P/.github/skills/api-docs/SKILL.md" "creó el de Copilot"

( cd "$P" && hogar_limpio -y --asistentes inventado . ) >/dev/null 2>&1
comprobar "rechaza un asistente desconocido con código 2" "$( [ "$?" = "2" ] && echo 0 || echo 1 )"

( cd "$P" && hogar_limpio -y --asistentes qoder --sin-enlaces . ) >/dev/null 2>&1
comprobar "rechaza combinar --asistentes con --sin-enlaces" "$( [ "$?" = "2" ] && echo 0 || echo 1 )"

titulo "11. Modo crear: trawun y <comando>"
P="$BASE/crear"
mkdir -p "$P"
( cd "$P" && hogar_limpio -y y mkdir mi-app ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe "$P/mi-app" "el comando de creación se ejecutó"
existe "$P/mi-app/AGENTS.md" "adaptó el proyecto recién creado"
existe "$P/mi-app/.agents/skills" "creó la estructura neutral"
existe "$P/mi-app/.git" "ofreció e inició el repositorio git"

titulo "12. Modo crear: los errores no se esconden"
P="$BASE/crear-falla"
mkdir -p "$P"
( cd "$P" && hogar_limpio -y y comando-que-no-existe-xyz ) >/dev/null 2>&1
comprobar "si el comando falla, sale 1" "$( [ "$?" = "1" ] && echo 0 || echo 1 )"
no_existe "$P/AGENTS.md" "no adaptó nada"

( cd "$P" && hogar_limpio -y y true ) >/dev/null 2>&1
comprobar "si no crea carpeta, sale 2" "$( [ "$?" = "2" ] && echo 0 || echo 1 )"
no_existe "$P/AGENTS.md" "tampoco adaptó la carpeta actual por error"

titulo "13. Modo crear en simulación: no ejecuta nada"
P="$BASE/crear-simulado"
mkdir -p "$P"
( cd "$P" && hogar_limpio -n y mkdir no-debe-crearse ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
no_existe "$P/no-debe-crearse" "no ejecutó el comando de creación"

# ---------------------------------------------------------------------------
printf '\n────────────────────────────────────────────\n'
if [ "$FALLOS" -gt 0 ]; then
    printf 'Fallaron %s prueba(s).\n\n' "$FALLOS"
    exit 1
fi

printf 'Todas las pruebas pasaron.\n\n'
rm -rf "$BASE"
