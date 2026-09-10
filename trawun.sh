#!/usr/bin/env bash
#
# Trawün — convenciones de agentes para tu proyecto
#
# Deja un proyecto listo para los asistentes que leen el estándar neutral: las
# reglas en AGENTS.md y los skills en .agents/skills. Los pocos que usan carpeta
# propia (Qoder, Copilot) reciben enlaces; el resto lee esas rutas directamente.
#
# Uso:  bash trawun.sh [opciones] [ruta-del-proyecto]        adapta lo que existe
#       bash trawun.sh [opciones] y <comando-de-creacion>    crea y adapta
#
# Este script trabaja SIEMPRE dentro del proyecto que le indiques. Nunca escribe
# en tu carpeta de usuario ni instala nada de forma global.
#
set -eu

VERSION="1.2.1"

# ---------------------------------------------------------------------------
# Presentación
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    TITULO=$'\033[1;36m'; OK=$'\033[32m'; AVISO=$'\033[33m'
    ERROR=$'\033[31m'; GRIS=$'\033[90m'; FIN=$'\033[0m'
else
    TITULO=""; OK=""; AVISO=""; ERROR=""; GRIS=""; FIN=""
fi

banner() {
    printf '\n%s' "$TITULO"
    cat <<'ARTE'
  ████████╗██████╗  █████╗ ██╗    ██╗ ██╗   ██╗███╗   ██╗
  ╚══██╔══╝██╔══██╗██╔══██╗██║    ██║ ██║   ██║████╗  ██║
     ██║   ██████╔╝███████║██║ █╗ ██║ ██║   ██║██╔██╗ ██║
     ██║   ██╔══██╗██╔══██║██║███╗██║ ██║   ██║██║╚██╗██║
     ██║   ██║  ██║██║  ██║╚███╔███╔╝ ╚██████╔╝██║ ╚████║
     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝   ╚═════╝ ╚═╝  ╚═══╝
ARTE
    printf '%s' "$FIN"
    printf '  %sTrawün%s · convenciones de agentes · v%s\n' "$GRIS" "$FIN" "$VERSION"
}

ayuda() {
    banner
    cat <<'AYUDA'

  Prepara un proyecto para los asistentes de IA que leen el estándar neutral:
  deja las reglas en AGENTS.md y los skills en .agents/skills.

  La mayoría lee esas rutas directamente y no necesita nada (DSH, Codex, Cursor,
  Zed, Amp, OpenCode). Unos pocos usan carpeta propia y reciben enlaces:
  Qoder (.qoder/skills) y Copilot (.github/skills).

  Qué hace, en orden:
    1. Averigua qué trae el proyecto (CLAUDE.md, .claude/, .mcp.json, Boost…).
    2. Te muestra el plan y te pide confirmación.
    3. Respalda lo que va a mover en .agentes-respaldo/ (nada se destruye).
    4. Mueve las reglas a AGENTS.md y los skills a .agents/skills.
    5. Si el proyecto usa Laravel Boost, lo redirige para que no revuelva.
    6. Crea los enlaces de los asistentes que correspondan.
    7. Verifica el resultado y te dice qué quedó pendiente de tu mano.

  Qué NO hace:
    · No escribe fuera del proyecto (nunca toca tu carpeta de usuario).
    · No instala skills de forma global.
    · No borra nada: lo que sobra se mueve a .agentes-respaldo/.
    · No hace commit: al final te muestra el diff y tú decides.
    · No inventa reglas: respeta el contenido que ya tengas.

  Uso:
    bash trawun.sh [opciones] [ruta]         adapta un proyecto que ya existe
    bash trawun.sh [opciones] y <comando>    crea un proyecto y lo adapta

  Opciones:
    -n, --dry-run         Muestra qué haría, sin tocar un solo archivo.
    -y, --si              Responde sí a todo. Útil para automatizar.
    --asistentes <lista>  Para qué asistentes crear enlaces, separados por
                          coma. Conocidos: qoder, copilot.
    --sin-enlaces         No crear enlaces de ningún asistente.
    -h, --ayuda           Muestra esta ayuda.
    -v, --version         Muestra la versión.

  Ejemplos:
    bash trawun.sh                          # adapta el proyecto actual
    bash trawun.sh -n                       # solo muestra el plan
    bash trawun.sh --asistentes qoder       # enlaces solo para Qoder
    bash trawun.sh --sin-enlaces            # sin enlaces de asistente
    bash trawun.sh y cargo new gestor       # crea el proyecto y lo adapta
AYUDA
}

ok()    { printf '     %s✓%s %s\n' "$OK" "$FIN" "$1"; }
aviso() { printf '     %s!%s %s\n' "$AVISO" "$FIN" "$1"; }
falla() { printf '     %s✗%s %s\n' "$ERROR" "$FIN" "$1"; }
nota()  { printf '       %s%s%s\n' "$GRIS" "$1" "$FIN"; }
paso()  { printf '\n%s==> %s%s\n' "$TITULO" "$1" "$FIN"; }

# ---------------------------------------------------------------------------
# Preguntas
#
# Con `curl | bash` la entrada estándar ES el script, así que leer de stdin
# consumiría el propio código. Por eso se lee siempre de /dev/tty.
# ---------------------------------------------------------------------------
RESPUESTA_SI="no"

hay_terminal() {
    # ¿Podemos preguntarle al usuario? Se comprueba abriendo /dev/tty de verdad:
    # el archivo puede existir y aun así no haber terminal (CI, contenedores).
    { exec 3</dev/tty; } 2>/dev/null || return 1
    exec 3<&-
    return 0
}

preguntar() {
    # $1 = pregunta, $2 = respuesta por defecto (s/n)
    if [ "$RESPUESTA_SI" = "si" ]; then
        return 0
    fi

    if ! hay_terminal; then
        aviso "Sin terminal interactiva: uso la opción por defecto ($2)."
        [ "$2" = "s" ] && return 0
        return 1
    fi

    printf '     %s [s/n] ' "$1"
    exec 3</dev/tty
    read -r respuesta <&3 || respuesta=""
    exec 3<&-

    [ -z "$respuesta" ] && respuesta="$2"

    case "$respuesta" in
        s|S|si|SI|Si|y|Y|yes) return 0 ;;
        no|n|N) return 1 ;;
        *) [ "$2" = "s" ] && return 0; return 1 ;;
    esac
}

confirmar_plan() {
    if [ "$RESPUESTA_SI" = "si" ]; then
        nota "Modo --si: se aplica el plan sin preguntar."
        return 0
    fi

    if ! hay_terminal; then
        printf '\n  %sNo hay terminal para pedirte confirmación, así que no toco nada.%s\n' "$AVISO" "$FIN"
        printf '  Si de verdad quieres aplicarlo sin preguntas: vuelve a correrlo con --si\n\n'
        exit 2
    fi

    if preguntar "¿Aplico estos cambios?" "s"; then
        return 0
    fi

    printf '\n  %sCancelado. No se tocó nada.%s\n\n' "$AVISO" "$FIN"
    exit 0
}

# ---------------------------------------------------------------------------
# Asistentes con carpeta propia
#
# La mayoría lee .agents/skills/ directamente y no necesita nada: DSH, Codex,
# Cursor, Zed, Amp, OpenCode y Antigravity. Cursor además lo documenta: entre
# sus rutas de skills lista .agents/skills/. Solo unos pocos usan carpeta
# propia, y esos son los que reciben enlaces.
# ---------------------------------------------------------------------------
ASISTENTES_CONOCIDOS="qoder copilot"

carpeta_asistente() {
    # Ruta de skills propia de cada asistente, relativa a la raíz del proyecto.
    case "$1" in
        qoder)   printf '.qoder/skills' ;;
        copilot) printf '.github/skills' ;;
        *)       printf '' ;;
    esac
}

# Carpetas donde cada asistente guarda sus skills. Todas se unifican en
# .agents/skills, que es lo que lee la mayoría.
FUENTES_SKILLS=".claude/skills .cursor/skills .github/skills .qoder/skills"

asistente_de_carpeta() {
    # A qué asistente pertenece una carpeta de skills (vacío = neutral).
    case "$1" in
        .claude/skills)  printf 'claude' ;;
        .cursor/skills)  printf 'cursor' ;;
        .github/skills)  printf 'copilot' ;;
        .qoder/skills)   printf 'qoder' ;;
        *)               printf '' ;;
    esac
}

necesita_enlace() {
    # ¿Este asistente lee .agents/skills por su cuenta?
    # Cursor sí (lo documenta); Qoder y Copilot no, usan carpeta propia.
    case "$1" in
        qoder|copilot) return 0 ;;
        *)             return 1 ;;
    esac
}

esta_en_asistentes() {
    for asistente_elegido in $ASISTENTES; do
        [ "$asistente_elegido" = "$1" ] && return 0
    done
    return 1
}

asistente_instalado() {
    # Pista para poder preguntar: ¿está instalado en esta máquina?
    case "$1" in
        qoder)   [ -d "$HOME/.qoder" ] ;;
        copilot) [ -d "$HOME/.copilot" ] ;;
        *)       return 1 ;;
    esac
}

usa_asistente() {
    # ¿El proyecto usa este asistente? Se mira su carpeta de skills, no la
    # carpeta a secas: un .github/ con workflows no significa usar Copilot.
    case "$1" in
        qoder)   [ -d .qoder ] ;;          # .qoder solo lo crea Qoder
        copilot) [ -d .github/skills ] ;;  # .github/ lo tiene casi cualquier repo
        *)       return 1 ;;
    esac
}

asistentes_detectados() {
    # Instalados en la máquina, o ya presentes en este proyecto.
    encontrados=""
    for asistente in $ASISTENTES_CONOCIDOS; do
        if asistente_instalado "$asistente" || usa_asistente "$asistente"; then
            encontrados="$encontrados $asistente"
        fi
    done
    printf '%s' "$(echo $encontrados)"
}

validar_asistentes() {
    # $1 = lista separada por comas. Devuelve la lista normalizada.
    for asistente in $(printf '%s' "$1" | tr ',' ' '); do
        case " $ASISTENTES_CONOCIDOS " in
            *" $asistente "*) ;;
            *)
                printf '%sAsistente desconocido: %s%s\n' "$ERROR" "$asistente" "$FIN" >&2
                printf 'Conocidos: %s\n' "$ASISTENTES_CONOCIDOS" >&2
                exit 2
                ;;
        esac
    done
    printf '%s' "$(printf '%s' "$1" | tr ',' ' ')"
}

elegir_asistentes() {
    # Deja en ASISTENTES la lista definitiva: por flag, o detectada y confirmada.
    if [ "$SIN_ENLACES" = "si" ]; then
        if [ -n "$ASISTENTES_PEDIDOS" ]; then
            printf '%sNo combines --asistentes con --sin-enlaces.%s\n' "$ERROR" "$FIN" >&2
            exit 2
        fi
        ASISTENTES=""
        return 0
    fi

    if [ -n "$ASISTENTES_PEDIDOS" ]; then
        ASISTENTES="$(validar_asistentes "$ASISTENTES_PEDIDOS")"
        return 0
    fi

    detectados="$(asistentes_detectados)"
    if [ -z "$detectados" ]; then
        ASISTENTES=""
        return 0
    fi

    printf '\n  %sDetecté instalado:%s %s\n' "$TITULO" "$FIN" "$detectados"
    nota "los enlaces solo hacen falta para asistentes con carpeta propia"
    nota "DSH, Codex, Cursor, Zed y compañía leen .agents/skills directamente"

    if preguntar "¿Creo los enlaces para $detectados?" "s"; then
        ASISTENTES="$detectados"
    else
        ASISTENTES=""
    fi
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
DRY_RUN="no"
RUTA=""
MODO="adaptar"
ASISTENTES_PEDIDOS=""
SIN_ENLACES="no"
ASISTENTES=""

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run)   DRY_RUN="si" ;;
        -y|--si)        RESPUESTA_SI="si" ;;
        --asistentes)   ASISTENTES_PEDIDOS="${2:-}"; shift ;;
        --sin-enlaces)  SIN_ENLACES="si" ;;
        -h|--ayuda)     ayuda; exit 0 ;;
        -v|--version)   printf 'trawun %s\n' "$VERSION"; exit 0 ;;
        y|crear)        MODO="crear"; shift; break ;;
        -*)             printf '%sOpción desconocida: %s%s\n' "$ERROR" "$1" "$FIN" >&2; exit 2 ;;
        *)              RUTA="$1" ;;
    esac
    shift
done

if [ "$MODO" = "crear" ] && [ $# -eq 0 ]; then
    printf '%sFalta el comando de creación.%s\n' "$ERROR" "$FIN" >&2
    printf 'Ejemplo: trawun y cargo new mi-proyecto\n' >&2
    exit 2
fi

if [ "$MODO" = "adaptar" ] && [ -n "$RUTA" ]; then
    if [ ! -d "$RUTA" ]; then
        printf '%sNo existe la carpeta: %s%s\n' "$ERROR" "$RUTA" "$FIN" >&2
        exit 2
    fi
    cd "$RUTA"
fi

PROYECTO="$(pwd)"PROYECTO="$(pwd)"

# ---------------------------------------------------------------------------
# Detección
# ---------------------------------------------------------------------------
HAY_CLAUDE_MD="no"; HAY_CLAUDE_DIR="no"; HAY_MCP="no"
HAY_AGENTS_MD="no"; HAY_AGENTS_SKILLS="no"; HAY_QODER="no"; HAY_BOOST="no"

detectar() {
    [ -f CLAUDE.md ]       && HAY_CLAUDE_MD="si"
    [ -d .claude ]         && HAY_CLAUDE_DIR="si"
    [ -f .mcp.json ]       && HAY_MCP="si"
    [ -f AGENTS.md ]       && HAY_AGENTS_MD="si"
    [ -d .agents/skills ]  && HAY_AGENTS_SKILLS="si"
    [ -d .qoder ]          && HAY_QODER="si"
    [ -d vendor/laravel/boost ] && HAY_BOOST="si"
    return 0
}

contar_skills() {
    # Cuenta los skills en $1: carpetas reales y enlaces a carpetas.
    # `find -type d` no sigue enlaces, por eso hay que mirarlos aparte.
    if [ -d "$1" ]; then
        find "$1" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

mostrar_plan() {
    banner
    printf '\n  Proyecto: %s%s%s\n' "$TITULO" "$PROYECTO" "$FIN"

    printf '\n  %sEncontré esto:%s\n' "$TITULO" "$FIN"
    if [ "$HAY_CLAUDE_MD" = "si" ]; then ok "CLAUDE.md (reglas para Claude Code)"; else nota "sin CLAUDE.md"; fi
    if [ "$HAY_CLAUDE_DIR" = "si" ]; then ok ".claude/ ($(contar_skills .claude/skills) skills de Claude Code)"; else nota "sin .claude/"; fi
    if [ "$HAY_MCP" = "si" ]; then ok ".mcp.json (servidores MCP)"; else nota "sin .mcp.json"; fi
    if [ "$HAY_AGENTS_MD" = "si" ]; then ok "AGENTS.md (ya está en el nombre neutral)"; fi
    if [ "$HAY_AGENTS_SKILLS" = "si" ]; then ok ".agents/skills ($(contar_skills .agents/skills) skills)"; fi
    if [ -d .cursor ]; then ok ".cursor/ (usa Cursor: lee .agents/skills, no necesita enlaces)"; fi
    if [ "$HAY_BOOST" = "si" ]; then ok "Laravel Boost (genera guías y skills)"; fi

    printf '\n  %sLo que voy a hacer:%s\n' "$TITULO" "$FIN"

    if [ "$HAY_CLAUDE_MD" = "si" ] && [ "$HAY_AGENTS_MD" = "no" ]; then
        ok "Mover CLAUDE.md  ->  AGENTS.md"
    elif [ "$HAY_CLAUDE_MD" = "si" ] && [ "$HAY_AGENTS_MD" = "si" ]; then
        aviso "Existen CLAUDE.md y AGENTS.md: los reviso pero NO los toco (hay que unirlos a mano)"
    fi

    if [ "$HAY_BOOST" = "si" ]; then
        ok "Redirigir Boost a las rutas neutrales y apagar su MCP"
    fi

    for carpeta_plan in $FUENTES_SKILLS; do
        [ "$(contar_skills "$carpeta_plan")" = "0" ] && continue
        asistente_plan="$(asistente_de_carpeta "$carpeta_plan")"

        # Cuántos de esos skills no están ya en la ruta neutral. Si no queda
        # ninguno, el plan no debe anunciar una mudanza que no va a ocurrir.
        pendientes=0
        for origen_plan in "$carpeta_plan"/*/; do
            [ -d "$origen_plan" ] || continue
            if [ ! -e ".agents/skills/$(basename "$origen_plan")" ]; then
                pendientes=$((pendientes + 1))
            fi
        done

        if [ "$pendientes" = "0" ]; then
            nota "Los skills de $carpeta_plan ya están en .agents/skills: nada que mover"
        elif necesita_enlace "$asistente_plan" && ! esta_en_asistentes "$asistente_plan"; then
            nota "Dejar los skills de $carpeta_plan donde están ($asistente_plan no lee la ruta neutral)"
        else
            ok "Mover los skills de $carpeta_plan  ->  .agents/skills"
        fi
    done

    if [ "$HAY_CLAUDE_DIR" = "si" ]; then
        ok "Respaldar .claude/ en .agentes-respaldo/ (no usas Claude Code)"
    fi

    if [ -n "$ASISTENTES" ]; then
        for asistente in $ASISTENTES; do
            ok "Crear los enlaces de $(carpeta_asistente "$asistente") hacia .agents/skills"
        done
    else
        nota "sin enlaces de asistente (solo AGENTS.md y .agents/skills)"
    fi

    if [ "$HAY_AGENTS_MD" = "no" ] && [ "$HAY_CLAUDE_MD" = "no" ]; then
        ok "Crear un AGENTS.md inicial para que lo completes"
    fi

    if [ "$HAY_MCP" = "si" ]; then
        aviso ".mcp.json: te pregunto aparte si lo conservo (Qoder sí lo lee)"
    fi

    nota "Nada se borra: lo que sobra va a .agentes-respaldo/"
    nota "No escribo fuera de este proyecto ni instalo nada global."
}

# ---------------------------------------------------------------------------
# Pasos
# ---------------------------------------------------------------------------
SELLO="$(date '+%Y%m%d-%H%M%S')"
RESPALDO=".agentes-respaldo/$SELLO"
RESPALDADOS=0

respaldar() {
    # $1 = ruta a mover, $2 = motivo
    [ -e "$1" ] || return 0

    if [ "$DRY_RUN" = "si" ]; then
        nota "[dry-run] movería $1 a $RESPALDO/"
        return 0
    fi

    mkdir -p "$RESPALDO"
    if [ ! -f "$RESPALDO/LEEME.txt" ]; then
        {
            printf 'Respaldo hecho por Trawün el %s\n\n' "$SELLO"
            printf 'Aquí está lo que el proyecto traía para Claude Code y que Trawün\n'
            printf 'movió para dejar las rutas neutrales. Nada se borró.\n\n'
            printf 'Para revertir: mueve estas carpetas a su lugar original.\n'
            printf 'Si todo funciona bien, puedes borrar esta carpeta entera.\n'
        } > "$RESPALDO/LEEME.txt"
    fi

    mv "$1" "$RESPALDO/"
    RESPALDADOS=$((RESPALDADOS + 1))
    ok "$1  ->  $RESPALDO/  ($2)"
}

paso_reglas() {
    [ "$HAY_CLAUDE_MD" = "si" ] || return 0
    [ "$HAY_AGENTS_MD" = "si" ] && return 0

    paso "1/6  Reglas: CLAUDE.md -> AGENTS.md"

    if [ "$DRY_RUN" = "si" ]; then
        nota "[dry-run] renombraría CLAUDE.md a AGENTS.md"
        return 0
    fi

    if git rev-parse --git-dir >/dev/null 2>&1 && [ -n "$(git ls-files -- CLAUDE.md 2>/dev/null)" ]; then
        git mv CLAUDE.md AGENTS.md
    else
        mv CLAUDE.md AGENTS.md
    fi
    ok "AGENTS.md listo (mismo contenido, nombre que sí leen DSH y Qoder)"
}

paso_boost() {
    [ "$HAY_BOOST" = "si" ] || return 0

    paso "2/6  Laravel Boost: redirigir sus rutas"

    if [ "$DRY_RUN" = "si" ]; then
        nota "[dry-run] escribiría config/boost.php y pondría \"mcp\": false en boost.json"
        nota "[dry-run] correría: php artisan boost:update"
        return 0
    fi

    if [ -f config/boost.php ]; then
        aviso "config/boost.php ya existe: no lo toco, revísalo a mano"
    else
        mkdir -p config
        cat > config/boost.php <<'PHP'
<?php

/*
|--------------------------------------------------------------------------
| Configuración de Laravel Boost
|--------------------------------------------------------------------------
|
| Boost escribe las guías para asistentes y los skills de desarrollo. Por
| defecto los deja en las rutas propias de Claude Code (`CLAUDE.md` y
| `.claude/skills`); este proyecto usa las rutas neutrales que entienden la
| mayoría de los asistentes (DSH, Qoder, Codex, Cursor, Amp, Zed, OpenCode):
| `AGENTS.md` y `.agents/skills`.
|
| Boost no trae un agente "neutral", así que se conserva `claude_code` en
| boost.json y se le redirigen las rutas aquí. Configurarlo (en vez de
| renombrar los archivos a mano) es lo que evita que `composer update` — que
| dispara `boost:update` — vuelva a crear los archivos antiguos y deje las
| guías duplicadas.
|
*/

return [
    'agents' => [
        'claude_code' => [
            'guidelines_path' => 'AGENTS.md',
            'skills_path' => '.agents/skills',
        ],
    ],
];
PHP
        ok "config/boost.php creado"
    fi

    if [ -f boost.json ]; then
        php -r '
$ruta = "boost.json";
$datos = json_decode((string) file_get_contents($ruta), true);
if (! is_array($datos)) { fwrite(STDERR, "boost.json no es JSON valido\n"); exit(1); }
$datos["mcp"] = false;
file_put_contents($ruta, json_encode($datos, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
' && ok "boost.json: MCP apagado (nada de herramientas fantasma en las guías)"
    fi

    respaldar ".claude" "Boost lo regenera en .agents/skills"

    if php artisan boost:update --no-interaction >/dev/null 2>&1; then
        ok "boost:update corrido: guías y skills reescritos en las rutas nuevas"
    else
        aviso "boost:update falló; córrelo a mano: php artisan boost:update"
    fi
}

paso_skills() {
    paso "3/6  Skills de cada asistente"

    if [ "$DRY_RUN" = "si" ]; then
        for carpeta in $FUENTES_SKILLS; do
            cantidad="$(contar_skills "$carpeta")"
            [ "$cantidad" = "0" ] && continue
            asistente="$(asistente_de_carpeta "$carpeta")"
            if necesita_enlace "$asistente" && ! esta_en_asistentes "$asistente"; then
                nota "[dry-run] dejaría $cantidad skill(s) en $carpeta"
                nota "  ($asistente no lee .agents/skills; moverlos sin enlace lo dejaría ciego)"
            else
                nota "[dry-run] movería $cantidad skill(s) de $carpeta a .agents/skills"
            fi
        done
        if [ "$HAY_CLAUDE_DIR" = "si" ]; then
            nota "[dry-run] movería .claude/ a .agentes-respaldo/"
        fi
        return 0
    fi

    movidos=0
    for carpeta in $FUENTES_SKILLS; do
        [ -d "$carpeta" ] || continue
        asistente="$(asistente_de_carpeta "$carpeta")"

        # Si el asistente no lee la ruta neutral y no vamos a dejarle enlaces,
        # mover sus skills lo dejaría sin verlos: mejor no tocarlos y avisar.
        if necesita_enlace "$asistente" && ! esta_en_asistentes "$asistente"; then
            if [ "$(contar_skills "$carpeta")" != "0" ]; then
                aviso "$carpeta tiene skills y $asistente no lee .agents/skills"
                nota "los dejo donde están; para unificarlos: trawun --asistentes $asistente"
            fi
            continue
        fi

        for origen in "$carpeta"/*/; do
            [ -d "$origen" ] || continue
            nombre="$(basename "$origen")"
            if [ -e ".agents/skills/$nombre" ]; then
                aviso "$nombre ya existe en .agents/skills: no lo piso (venía de $carpeta)"
                continue
            fi
            mkdir -p .agents/skills
            mv "$origen" ".agents/skills/$nombre"
            ok "$nombre  ($carpeta -> .agents/skills)"
            movidos=$((movidos + 1))
        done
    done

    if [ "$movidos" = "0" ] && [ "$HAY_CLAUDE_DIR" = "no" ]; then
        nota "no encontré skills que mover"
    fi

    # Claude Code sí se respalda entero: este proyecto no lo usa, y sus comandos
    # y agentes propios no aplican. Queda recuperable en .agentes-respaldo/.
    if [ "$HAY_CLAUDE_DIR" = "si" ]; then
        quedan="$(find .claude -mindepth 1 -maxdepth 1 ! -name skills 2>/dev/null | sed 's|^\.claude/||' | tr '\n' ' ')"
        if [ -n "$quedan" ]; then
            aviso "además va al respaldo, y no son skills: $quedan"
        fi
        respaldar ".claude" "configuración de Claude Code"
    fi
}

paso_enlaces() {
    if [ -z "$ASISTENTES" ]; then
        paso "5/6  Enlaces de asistentes"
        nota "ninguno: DSH, Codex, Cursor, Zed y compañía leen .agents/skills directo"
        return 0
    fi

    paso "5/6  Enlaces de asistentes"

    if [ "$DRY_RUN" = "si" ]; then
        # En simulación .agents/skills puede no existir aún: se cuenta lo que
        # quedaría ahí después de mover los skills.
        previstos="$(contar_skills .agents/skills)"
        if [ "$previstos" = "0" ]; then
            for carpeta_sim in $FUENTES_SKILLS; do
                previstos=$((previstos + $(contar_skills "$carpeta_sim")))
            done
        fi
        for asistente in $ASISTENTES; do
            nota "[dry-run] crearía $previstos enlace(s) en $(carpeta_asistente "$asistente")"
        done
        return 0
    fi

    if [ ! -d .agents/skills ]; then
        aviso "No hay .agents/skills todavía: no hay nada que enlazar"
        nota "Cuando agregues skills ahí, vuelve a correr Trawün."
        return 0
    fi

    for asistente in $ASISTENTES; do
        destino="$(carpeta_asistente "$asistente")"
        mkdir -p "$destino"
        enlazados=0
        copiados=0

        for origen in .agents/skills/*/; do
            [ -d "$origen" ] || continue
            nombre="$(basename "$origen")"

            if [ -e "$destino/$nombre" ] && [ ! -L "$destino/$nombre" ]; then
                aviso "$nombre ya existe en $destino como carpeta real: no lo toco"
                continue
            fi

            ln -sfn "../../.agents/skills/$nombre" "$destino/$nombre" 2>/dev/null || true

            if [ -e "$destino/$nombre" ]; then
                enlazados=$((enlazados + 1))
            else
                # Hay sistemas que no permiten enlaces (Windows sin permisos,
                # algunos sistemas de archivos). Ahí se copia: ocupa más, y hay
                # que volver a correr Trawün si el skill cambia.
                rm -rf "$destino/$nombre"
                cp -R ".agents/skills/$nombre" "$destino/$nombre"
                copiados=$((copiados + 1))
            fi
        done

        if [ "$enlazados" -gt 0 ]; then
            ok "$asistente: $enlazados enlace(s) en $destino"
        fi
        if [ "$copiados" -gt 0 ]; then
            aviso "$asistente: $copiados copia(s) en $destino (este sistema no permite enlaces)"
            nota "si cambias esos skills, vuelve a correr Trawün"
        fi
    done
}

paso_mcp() {
    [ "$HAY_MCP" = "si" ] || return 0

    paso "6/6  Servidores MCP (.mcp.json)"

    nota "Qoder SÍ lee .mcp.json de este proyecto; DSH necesita un plugin aparte."
    nota "Cada servidor MCP suma sus herramientas a cada mensaje que envíes."

    if preguntar "¿Conservo .mcp.json?" "s"; then
        ok "Se conserva: revisa que los servidores que declara sean los que quieres"
    else
        respaldar ".mcp.json" "no lo quieres usar por ahora"
    fi
}

paso_sembrar() {
    paso "4/6  Lo que faltaba por crear"

    if [ "$DRY_RUN" = "si" ]; then
        nota "[dry-run] crearía AGENTS.md y .agents/skills si faltan"
        return 0
    fi

    if [ ! -f AGENTS.md ]; then
        cat > AGENTS.md <<'MD'
# Reglas del proyecto

> Este archivo lo leen los asistentes de IA (DSH, Qoder, Codex, Cursor, Zed…).
> Trawün lo creó vacío a propósito: escríbelo tú, con las reglas reales del
> proyecto. Un archivo corto y concreto rinde más que uno largo y genérico.

## Qué es este proyecto

(Pendiente: una o dos frases.)

## Cómo se trabaja aquí

- (Pendiente: comandos que se corren antes de dar algo por terminado.)
- (Pendiente: convenciones de nombres, idioma, formato.)

## Trampas conocidas

- (Pendiente: lo que ya te costó tiempo una vez.)

## Archivos para asistentes

Los skills de este proyecto viven en `.agents/skills/`, y `.qoder/skills/` tiene
enlaces a ellos. Los skills son de este proyecto y de ningún otro: no se instalan
de forma global.
MD
        ok "AGENTS.md creado (con secciones para completar)"
    fi

    if [ ! -d .agents/skills ]; then
        mkdir -p .agents/skills
        cat > .agents/skills/LEEME.md <<'MD'
# Skills de este proyecto

Cada skill vive en su propia carpeta: `.agents/skills/<nombre>/SKILL.md`, con
frontmatter YAML que incluya `name` y `description`.

Los skills de este proyecto son de este proyecto. No se instalan de forma global:
si los pusieras en tu carpeta de usuario, aparecerían en todos los demás
proyectos tuyos, incluso donde no tienen nada que hacer.

`.qoder/skills/` contiene enlaces a estas carpetas, para que Qoder los vea sin
duplicar archivos.
MD
        ok ".agents/skills/ creado con un LEEME que explica la convención"
    fi

    [ -f AGENTS.md ] && [ -d .agents/skills ] || return 0
}

# ---------------------------------------------------------------------------
# Verificación
# ---------------------------------------------------------------------------
FALLOS=0

comprobar() {
    # $1 = descripción, $2 = valor, $3 = esperado
    if [ "$2" = "$3" ]; then
        ok "$1: $2"
    else
        falla "$1: $2 (esperaba $3)"
        FALLOS=$((FALLOS + 1))
    fi
}

verificar() {
    paso "Verificación"

    comprobar "AGENTS.md" "$([ -f AGENTS.md ] && echo presente || echo ausente)" "presente"
    comprobar ".agents/skills" "$([ -d .agents/skills ] && echo presente || echo ausente)" "presente"
    comprobar "CLAUDE.md" "$([ -f CLAUDE.md ] && echo presente || echo ausente)" "ausente"
    comprobar ".claude/" "$([ -d .claude ] && echo presente || echo ausente)" "ausente"

    esperados="$(contar_skills .agents/skills)"

    if [ -z "$ASISTENTES" ]; then
        nota "sin enlaces de asistente: no hay nada que revisar aquí"
    else
        for asistente in $ASISTENTES; do
            destino="$(carpeta_asistente "$asistente")"
            comprobar "$asistente: enlaces en $destino" "$(contar_skills "$destino")" "$esperados"

            rotos=0
            for enlace in "$destino"/*; do
                # Se recorren todos los elementos (no solo directorios) porque un
                # enlace quebrado deja de ser un directorio y hay que verlo igual.
                [ -L "$enlace" ] || continue
                [ -e "$enlace" ] || rotos=$((rotos + 1))
            done

            if [ "$rotos" -gt 0 ]; then
                falla "$asistente: $rotos enlace(s) roto(s)"
                FALLOS=$((FALLOS + 1))
            else
                ok "$asistente: todos los enlaces resuelven"
            fi
        done
    fi
}

resumen() {
    printf '\n%s────────────────────────────────────────────────────────────%s\n' "$GRIS" "$FIN"

    if [ "$FALLOS" -gt 0 ]; then
        printf '\n  %sQuedaron %s problema(s). Revisa arriba.%s\n\n' "$ERROR" "$FALLOS" "$FIN"
        exit 1
    fi

    if [ "$DRY_RUN" = "si" ]; then
        printf '\n  %sSimulación terminada. No se tocó nada.%s\n' "$OK" "$FIN"
        printf '  Corre sin --dry-run para aplicarlo.\n\n'
        exit 0
    fi

    printf '\n  %sListo.%s\n\n' "$OK" "$FIN"
    printf '  Los asistentes que leen AGENTS.md y .agents/skills ya ven este proyecto\n'
    printf '  como corresponde: DSH, Codex, Cursor, Zed y compañía usan esas rutas\n'
    printf '  directamente.\n\n'

    if [ -n "$ASISTENTES" ]; then
        for asistente in $ASISTENTES; do
            printf '  Enlaces creados para %s%s%s en %s\n' "$TITULO" "$asistente" "$FIN" "$(carpeta_asistente "$asistente")"
        done
        printf '\n'
    else
        printf '  No creé enlaces de asistente. Si usas Qoder o Copilot:\n'
        printf '    trawun --asistentes qoder,copilot\n\n'
    fi

    if [ "$RESPALDADOS" -gt 0 ]; then
        printf '  %sRespaldé %s cosa(s) en %s/%s\n' "$AVISO" "$RESPALDADOS" "$RESPALDO" "$FIN"
        printf '  Si todo anda bien, borra esa carpeta.\n\n'
    fi

    printf '  1. Revisa el diff:   git status && git diff\n'
    printf '  2. Commitea:         git add -A && git commit -m "chore: convenciones de agentes"\n\n'
}

# ---------------------------------------------------------------------------
# Modo crear: corre el comando de creación y adapta lo que aparezca
# ---------------------------------------------------------------------------
crear_proyecto() {
    # "$@" = el comando de creación, tal cual lo escribió el usuario.
    banner
    printf '\n  Proyecto nuevo en: %s%s%s\n' "$TITULO" "$(pwd)" "$FIN"
    printf '  Comando: %s%s%s\n' "$TITULO" "$*" "$FIN"

    if [ "$DRY_RUN" = "si" ]; then
        printf '\n  %sEn simulación no puedo mostrarte el plan: todavía no existe el\n' "$AVISO"
        printf '  proyecto, y crearlo es justamente lo que la simulación evita.%s\n' "$FIN"
        printf '  Corre el comando sin -n cuando quieras hacerlo de verdad.\n\n'
        exit 0
    fi

    printf '\n'

    # Se anota qué hay antes para descubrir la carpeta nueva por diferencia:
    # adivinar el nombre desde los argumentos falla, porque los generadores no
    # siempre lo respetan.
    antes="$(ls -A1 2>/dev/null | sort)"
    codigo=0

    # El generador necesita tu terminal: si venimos de `curl | bash`, la entrada
    # estándar es el script, así que se le pasa /dev/tty explícitamente.
    if hay_terminal; then
        "$@" < /dev/tty || codigo=$?
    else
        "$@" || codigo=$?
    fi

    if [ "$codigo" != "0" ]; then
        printf '\n'
        falla "el comando de creación falló (código $codigo)"
        printf '  No adapto nada. Revisa el error de arriba.\n\n'
        exit 1
    fi

    despues="$(ls -A1 2>/dev/null | sort)"
    nuevos="$(comm -13 <(printf '%s\n' "$antes") <(printf '%s\n' "$despues") | grep -v '^$' || true)"

    cuantos=0
    for elemento in $nuevos; do
        cuantos=$((cuantos + 1))
    done

    if [ "$cuantos" = "0" ]; then
        aviso "El comando no creó ninguna carpeta nueva."
        nota "Si escribió aquí mismo (cargo init, npm init), entra a la carpeta"
        nota "del proyecto y corre trawun ahí."
        printf '\n'
        exit 2
    fi

    if [ "$cuantos" -gt 1 ]; then
        aviso "Aparecieron varios elementos nuevos:"
        for elemento in $nuevos; do
            nota "  $elemento"
        done
        printf '\n  Entra a la carpeta del proyecto y corre trawun ahí.\n\n'
        exit 2
    fi

    if [ ! -d "$nuevos" ]; then
        falla "lo que apareció no es una carpeta: $nuevos"
        printf '\n'
        exit 2
    fi

    cd "$nuevos"
    ok "proyecto creado: $nuevos"

    # DSH busca la raíz del proyecto subiendo hasta encontrar .git. Sin repo
    # funciona igual mientras se abra en la carpeta exacta, pero no desde una
    # subcarpeta. Por eso se ofrece, nunca se hace solo.
    if [ ! -d .git ]; then
        if preguntar "¿Inicializo un repositorio git? (ayuda a ubicar la raíz)" "s"; then
            if git init -q . 2>/dev/null; then
                ok "repositorio git iniciado"
            else
                aviso "no pude iniciar el repositorio (¿está instalado git?)"
            fi
        fi
    fi
}

# ---------------------------------------------------------------------------
main() {
    if [ "$MODO" = "crear" ]; then
        crear_proyecto "$@"
    fi

    PROYECTO="$(pwd)"
    detectar
    elegir_asistentes
    mostrar_plan

    # La simulación no cambia nada, así que no pide confirmación.
    if [ "$DRY_RUN" != "si" ]; then
        confirmar_plan
    fi

    if [ "$DRY_RUN" = "si" ]; then
        printf '\n%s── modo dry-run: no se toca ningún archivo ──%s\n' "$AVISO" "$FIN"
    fi

    paso_reglas
    paso_boost
    paso_skills
    paso_sembrar
    paso_enlaces
    paso_mcp

    if [ "$DRY_RUN" = "si" ]; then
        paso "Verificación"
        nota "[dry-run] no hay nada que verificar"
        printf '\n  %sSimulación terminada. No se tocó nada.%s\n\n' "$OK" "$FIN"
        exit 0
    fi

    verificar
    resumen
}

main "$@"
