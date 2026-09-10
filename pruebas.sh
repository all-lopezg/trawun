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

comprobar() {
    # $1 = descripción, $2 = 0 si pasó
    if [ "$2" = "0" ]; then
        printf '  %s✓%s %s\n' "$( [ -t 1 ] && printf '\033[32m' )" "$( [ -t 1 ] && printf '\033[0m' )" "$1"
    else
        printf '  %s✗%s %s\n' "$( [ -t 1 ] && printf '\033[31m' )" "$( [ -t 1 ] && printf '\033[0m' )" "$1"
        FALLOS=$((FALLOS + 1))
    fi
}

existe()    { [ -e "$1" ];  comprobar "$2" "$?"; }
no_existe() { [ ! -e "$1" ]; comprobar "$2" "$?"; }

titulo() { printf '\n%s\n' "$1"; }

# ---------------------------------------------------------------------------
titulo "1. Proyecto completo (reglas, skills, comandos y .mcp.json)"
P="$BASE/completo"
mkdir -p "$P/.claude/skills/api-docs" "$P/.claude/commands"
printf '# Reglas\n' > "$P/CLAUDE.md"
printf -- '---\nname: api-docs\ndescription: Prueba.\n---\n' > "$P/.claude/skills/api-docs/SKILL.md"
printf 'x\n' > "$P/.claude/commands/deploy.md"
printf '{}\n' > "$P/.mcp.json"
( cd "$P" && git init -q . && git add -A && git commit -qm inicial )
( cd "$P" && bash "$TRAWUN" -y . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe    "$P/AGENTS.md" "las reglas quedaron en AGENTS.md"
existe    "$P/.agents/skills/api-docs/SKILL.md" "el skill se movió a .agents/skills"
existe    "$P/.qoder/skills/api-docs/SKILL.md" "Qoder ve el skill por el enlace"
no_existe "$P/CLAUDE.md" "CLAUDE.md ya no está"
no_existe "$P/.claude" "no quedó .claude/"
existe    "$P/.mcp.json" ".mcp.json se conservó (Qoder lo lee)"
existe    "$P/.agentes-respaldo" "hay respaldo de lo que se movió"

titulo "2. Idempotencia (correrlo dos veces)"
( cd "$P" && bash "$TRAWUN" -y . ) >/dev/null 2>&1
comprobar "la segunda corrida también sale 0" "$?"
existe "$P/.agents/skills/api-docs/SKILL.md" "no duplicó ni rompió nada"

titulo "3. .claude/ sin carpeta de skills"
P="$BASE/sin-skills"
mkdir -p "$P/.claude/commands"
printf '# Reglas\n' > "$P/CLAUDE.md"
printf 'x\n' > "$P/.claude/commands/deploy.md"
( cd "$P" && bash "$TRAWUN" -y . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
no_existe "$P/.claude" ".claude/ se fue al respaldo"
existe "$P/.agentes-respaldo" "el comando propio quedó respaldado"

titulo "4. Proyecto vacío (modo sembrar)"
P="$BASE/vacio"
mkdir -p "$P"
printf 'x\n' > "$P/README.md"
( cd "$P" && bash "$TRAWUN" -y . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe "$P/AGENTS.md" "creó un AGENTS.md para completar"
existe "$P/.agents/skills" "creó .agents/skills"
existe "$P/.qoder/skills" "creó .qoder/skills"

titulo "5. Simulación (--dry-run) no toca nada"
P="$BASE/simular"
mkdir -p "$P"
printf '# Reglas\n' > "$P/CLAUDE.md"
( cd "$P" && bash "$TRAWUN" -n . ) >/dev/null 2>&1
comprobar "sale con código 0" "$?"
existe    "$P/CLAUDE.md" "CLAUDE.md sigue igual"
no_existe "$P/AGENTS.md" "no creó AGENTS.md"
no_existe "$P/.agentes-respaldo" "no creó respaldo"

titulo "6. Sin terminal y sin --si: se niega a adivinar"
P="$BASE/sin-terminal"
mkdir -p "$P"
printf '# Reglas\n' > "$P/CLAUDE.md"
( cd "$P" && bash "$TRAWUN" . </dev/null ) >/dev/null 2>&1
codigo=$?
comprobar "sale con código 2" "$( [ "$codigo" = "2" ] && echo 0 || echo 1 )"
existe    "$P/CLAUDE.md" "no tocó CLAUDE.md"
no_existe "$P/AGENTS.md" "no creó AGENTS.md"

# ---------------------------------------------------------------------------
printf '\n────────────────────────────────────────────\n'
if [ "$FALLOS" -gt 0 ]; then
    printf 'Fallaron %s prueba(s).\n\n' "$FALLOS"
    exit 1
fi

printf 'Todas las pruebas pasaron.\n\n'
rm -rf "$BASE"
