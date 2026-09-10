#!/usr/bin/env bash
#
# Trawün — convenciones de agentes para tu proyecto
#
# Deja un proyecto listo para los asistentes que leen el estándar neutral: las
# reglas en AGENTS.md y los skills en .agents/skills. Los pocos que usan carpeta
# propia (Qoder, Copilot) reciben enlaces; el resto lee esas rutas directamente.
#
# Habla español e inglés. El idioma se elige con --idioma, con la variable
# TRAWUN_IDIOMA, o se pregunta al empezar; sin terminal se deduce del sistema.
#
# Uso:  bash trawun.sh [opciones] [ruta-del-proyecto]        adapta lo que existe
#       bash trawun.sh [opciones] y <comando-de-creacion>    crea y adapta
#
# Este script trabaja SIEMPRE dentro del proyecto que le indiques. Nunca escribe
# en tu carpeta de usuario ni instala nada de forma global.
#
set -eu

VERSION="1.3.0"

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
    decir banner_linea "$VERSION"
}

# ---------------------------------------------------------------------------
# Idioma
#
# Todo el texto que ve el usuario vive en dos catálogos con las mismas claves
# (mensaje_es y mensaje_en, al final del archivo). `decir <clave> [datos]` llama
# al del idioma activo, así que el resto del script no repite un `if` de idioma
# por mensaje: los ayudantes ok/aviso/falla/nota/paso piden el texto con `decir`.
#
# Agregar un idioma es escribir otro mensaje_xx con las mismas claves y sus
# plantillas; hay una prueba que compara las claves para que ninguna quede sin
# traducir.
# ---------------------------------------------------------------------------
IDIOMA="es"
IDIOMA_PEDIDO=""
IDIOMA_DADO="no"
PREGUNTAR_IDIOMA="si"

decir() {
    "mensaje_$IDIOMA" "$@"
}

normalizar_idioma() {
    # Acepta es, es_AR.UTF-8, español, castellano, en, en_US, english, inglés…
    case "$1" in
        [Ee][Ss]|[Ee][Ss][-_]*|[Ee]spanol|[Ee]spañol|[Cc]astellano|1) printf 'es' ;;
        [Ee][Nn]|[Ee][Nn][-_]*|[Ee]nglish|[Ii]ngles|[Ii]nglés|2)       printf 'en' ;;
        *)                                                            printf '' ;;
    esac
}

idioma_del_sistema() {
    # Solo una pista para la opción por defecto: el idioma de la máquina no
    # siempre es el que quiere quien corre el script.
    for valor in "${LC_ALL:-}" "${LC_MESSAGES:-}" "${LANG:-}"; do
        encontrado="$(normalizar_idioma "$valor")"
        [ -n "$encontrado" ] && { printf '%s' "$encontrado"; return 0; }
    done

    # En macOS LANG suele estar vacío y el idioma vive en las preferencias.
    if [ "$(uname -s)" = "Darwin" ] && command -v defaults >/dev/null 2>&1; then
        encontrado="$(normalizar_idioma "$(defaults read -g AppleLocale 2>/dev/null || true)")"
        [ -n "$encontrado" ] && { printf '%s' "$encontrado"; return 0; }
    fi

    printf 'es'
}

preguntar_idioma() {
    # La pregunta va en los dos idiomas: todavía no hay uno elegido. Se lee de
    # /dev/tty porque con `curl | bash` la entrada estándar es el script.
    printf '\n     ¿En qué idioma? / Which language?  [es/en] (enter = %s) ' "$IDIOMA"
    exec 3</dev/tty
    read -r respuesta <&3 || respuesta=""
    exec 3<&-

    [ -z "$respuesta" ] && return 0

    elegido="$(normalizar_idioma "$respuesta")"
    [ -n "$elegido" ] && IDIOMA="$elegido"
    return 0
}

elegir_idioma() {
    # Prioridad: la bandera, la variable de entorno, y si no se pregunta. Lo
    # elegido a mano manda sobre el idioma de la máquina, siempre.
    IDIOMA="$(idioma_del_sistema)"

    if [ -z "$IDIOMA_PEDIDO" ]; then
        IDIOMA_PEDIDO="${TRAWUN_IDIOMA:-}"
    fi
    if [ -z "$IDIOMA_PEDIDO" ]; then
        IDIOMA_PEDIDO="${TRAWUN_LANG:-}"
    fi

    if [ -n "$IDIOMA_PEDIDO" ] || [ "$IDIOMA_DADO" = "si" ]; then
        elegido="$(normalizar_idioma "$IDIOMA_PEDIDO")"
        if [ -z "$elegido" ]; then
            printf '%s%s%s\n' "$ERROR" "$(decir idioma_desconocido "$IDIOMA_PEDIDO")" "$FIN" >&2
            printf '%s\n' "$(decir idioma_conocidos)" >&2
            exit 2
        fi
        IDIOMA="$elegido"
        return 0
    fi

    if [ "$PREGUNTAR_IDIOMA" = "si" ] && [ "$RESPUESTA_SI" != "si" ] && hay_terminal; then
        preguntar_idioma
    fi
}

# ---------------------------------------------------------------------------
# Salida
# ---------------------------------------------------------------------------
ok()    { printf '     %s✓%s %s\n' "$OK" "$FIN" "$(decir "$@")"; }
aviso() { printf '     %s!%s %s\n' "$AVISO" "$FIN" "$(decir "$@")"; }
falla() { printf '     %s✗%s %s\n' "$ERROR" "$FIN" "$(decir "$@")"; }
nota()  { printf '       %s%s%s\n' "$GRIS" "$(decir "$@")" "$FIN"; }
# Dato crudo: rutas, nombres de archivo y demás texto que no se traduce.
dato()  { printf '       %s%s%s\n' "$GRIS" "$1" "$FIN"; }

# Los pasos se numeran sobre los que de verdad van a correr. Antes el número
# venía escrito en cada título, así que un proyecto sin CLAUDE.md ni Boost
# empezaba en "3/6" y parecía que dos pasos habían fallado en silencio.
PASO_NUM=0
PASOS_TOTAL=0
paso() {
    PASO_NUM=$((PASO_NUM + 1))
    printf '\n%s==> %s/%s  %s%s\n' "$TITULO" "$PASO_NUM" "$PASOS_TOTAL" "$(decir "$@")" "$FIN"
}

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
    # $1 = clave de la pregunta, $2 = respuesta por defecto (si/no), resto = los
    # datos que la pregunta necesite. Los datos empiezan en $3 para que el
    # catálogo los reciba en $2, igual que cualquier otro mensaje.
    if [ "$RESPUESTA_SI" = "si" ]; then
        return 0
    fi

    if ! hay_terminal; then
        if [ "$2" = "si" ]; then
            aviso pregunta_sin_terminal "$(decir defecto_si)"
        else
            aviso pregunta_sin_terminal "$(decir defecto_no)"
        fi
        [ "$2" = "si" ] && return 0
        return 1
    fi

    printf '     %s%s' "$(decir "$1" "${@:3}")" "$(decir pregunta_sufijo)"
    exec 3</dev/tty
    read -r respuesta <&3 || respuesta=""
    exec 3<&-

    [ -z "$respuesta" ] && respuesta="$2"

    case "$respuesta" in
        s|S|si|SI|Si|y|Y|yes) return 0 ;;
        no|n|N) return 1 ;;
        *) [ "$2" = "si" ] && return 0; return 1 ;;
    esac
}

confirmar_plan() {
    if [ "$RESPUESTA_SI" = "si" ]; then
        nota confirmar_modo_si
        return 0
    fi

    if ! hay_terminal; then
        printf '\n  %s%s%s\n' "$AVISO" "$(decir confirmar_sin_terminal)" "$FIN"
        printf '  %s\n\n' "$(decir confirmar_sin_terminal_2)"
        exit 2
    fi

    if preguntar confirmar_pregunta si; then
        return 0
    fi

    printf '\n  %s%s%s\n\n' "$AVISO" "$(decir confirmar_cancelado)" "$FIN"
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
                printf '%s%s%s\n' "$ERROR" "$(decir asistente_desconocido "$asistente")" "$FIN" >&2
                printf '%s\n' "$(decir asistente_conocidos "$ASISTENTES_CONOCIDOS")" >&2
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
            printf '%s%s%s\n' "$ERROR" "$(decir error_enlaces_contradiccion)" "$FIN" >&2
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

    decir asistente_detectados "$detectados"
    nota asistente_nota_1
    nota asistente_nota_2

    if preguntar asistente_pregunta si "$detectados"; then
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
OPCION_MALA=""
OPCION_SIN_VALOR=""
PEDIR_AYUDA="no"
PEDIR_VERSION="no"

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

skills_previstos() {
    # Cuántos skills van a quedar en .agents/skills: los que ya están más los que
    # se van a mover. Solo se usa para decidir si hay algo que enlazar (los
    # duplicados que no se pisan cuentan de más, y da igual: nunca da 0 con
    # skills de verdad).
    total_previsto="$(contar_skills .agents/skills)"
    for carpeta_prevista in $FUENTES_SKILLS; do
        asistente_previsto="$(asistente_de_carpeta "$carpeta_prevista")"
        if necesita_enlace "$asistente_previsto" && ! esta_en_asistentes "$asistente_previsto"; then
            continue
        fi
        total_previsto=$((total_previsto + $(contar_skills "$carpeta_prevista")))
    done
    printf '%s' "$total_previsto"
}

prever_pasos() {
    # Cuántos pasos van a imprimir título, para poder numerarlos. Las condiciones
    # son las mismas que usan las funciones de más abajo: si cambia una, cambia
    # la otra, o la numeración vuelve a mentir.
    total=0
    if [ "$HAY_CLAUDE_MD" = "si" ] && [ "$HAY_AGENTS_MD" = "no" ]; then
        total=$((total + 1))
    fi
    if [ "$HAY_BOOST" = "si" ]; then
        total=$((total + 1))
    fi
    total=$((total + 3))         # skills, siembra y enlaces: siempre dicen algo
    if [ "$HAY_MCP" = "si" ]; then
        total=$((total + 1))
    fi
    PASOS_TOTAL=$((total + 1))   # la verificación del final
}

frase_skills() {
    # Qué decir de los skills en los archivos que sembramos. Solo se afirma que
    # hay enlaces si de verdad se van a crear: prometerlos en el AGENTS.md de un
    # proyecto sin skills deja una mentira en el archivo que lee el asistente.
    if [ -n "$ASISTENTES" ] && [ "$(contar_skills .agents/skills)" != "0" ]; then
        lista_enlaces=""
        for asistente_frase in $ASISTENTES; do
            enlace_frase="$(printf '`%s/`' "$(carpeta_asistente "$asistente_frase")")"
            if [ -z "$lista_enlaces" ]; then
                lista_enlaces="$enlace_frase"
            else
                lista_enlaces="$lista_enlaces, $enlace_frase"
            fi
        done
        decir frase_con_enlaces "$lista_enlaces"
    else
        decir frase_sin_enlaces
    fi
}

mostrar_plan() {
    banner
    decir plan_proyecto "$PROYECTO"

    decir plan_encontre
    if [ "$HAY_CLAUDE_MD" = "si" ]; then ok plan_tiene_claude_md; else nota plan_sin_claude_md; fi
    if [ "$HAY_CLAUDE_DIR" = "si" ]; then ok plan_tiene_claude_dir "$(contar_skills .claude/skills)"; else nota plan_sin_claude_dir; fi
    if [ "$HAY_MCP" = "si" ]; then ok plan_tiene_mcp; else nota plan_sin_mcp; fi
    if [ "$HAY_AGENTS_MD" = "si" ]; then ok plan_tiene_agents_md; fi
    if [ "$HAY_AGENTS_SKILLS" = "si" ]; then ok plan_tiene_agents_skills "$(contar_skills .agents/skills)"; fi
    if [ -d .cursor ]; then ok plan_cursor; fi
    if [ "$HAY_BOOST" = "si" ]; then ok plan_boost; fi

    decir plan_hare

    if [ "$HAY_CLAUDE_MD" = "si" ] && [ "$HAY_AGENTS_MD" = "no" ]; then
        ok plan_mover_reglas
    elif [ "$HAY_CLAUDE_MD" = "si" ] && [ "$HAY_AGENTS_MD" = "si" ]; then
        aviso plan_dos_reglas
    fi

    if [ "$HAY_BOOST" = "si" ]; then
        ok plan_boost_hacer
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
            nota plan_skills_ya "$carpeta_plan"
        elif necesita_enlace "$asistente_plan" && ! esta_en_asistentes "$asistente_plan"; then
            nota plan_skills_dejar "$carpeta_plan" "$asistente_plan"
        else
            ok plan_skills_mover "$carpeta_plan"
        fi
    done

    if [ "$HAY_CLAUDE_DIR" = "si" ]; then
        ok plan_respaldar_claude
    fi

    if [ -n "$ASISTENTES" ]; then
        # Solo se anuncia lo que va a pasar: en un proyecto sin skills, los
        # enlaces no se crean y el plan no puede prometerlos.
        if [ "$(skills_previstos)" = "0" ]; then
            nota plan_enlaces_nada
        else
            for asistente in $ASISTENTES; do
                ok plan_enlaces_crear "$(carpeta_asistente "$asistente")"
            done
        fi
    else
        nota plan_sin_enlaces
    fi

    if [ "$HAY_AGENTS_MD" = "no" ] && [ "$HAY_CLAUDE_MD" = "no" ]; then
        ok plan_sembrar
    fi

    if [ "$HAY_MCP" = "si" ]; then
        aviso plan_mcp_pregunta
    fi

    nota plan_nada_se_borra
    nota plan_no_escribo
}

# ---------------------------------------------------------------------------
# Pasos
# ---------------------------------------------------------------------------
SELLO="$(date '+%Y%m%d-%H%M%S')"
RESPALDO=".agentes-respaldo/$SELLO"
RESPALDADOS=0
ENLACES_HECHOS=0

respaldar() {
    # $1 = ruta a mover, $2 = clave del motivo
    [ -e "$1" ] || return 0

    if [ "$DRY_RUN" = "si" ]; then
        nota respaldo_dry "$1" "$RESPALDO"
        return 0
    fi

    mkdir -p "$RESPALDO"
    if [ ! -f "$RESPALDO/README.txt" ]; then
        decir respaldo_txt "$SELLO" > "$RESPALDO/README.txt"
    fi

    mv "$1" "$RESPALDO/"
    RESPALDADOS=$((RESPALDADOS + 1))
    ok respaldo_hecho "$1" "$RESPALDO" "$(decir "$2")"
}

paso_reglas() {
    [ "$HAY_CLAUDE_MD" = "si" ] || return 0
    [ "$HAY_AGENTS_MD" = "si" ] && return 0

    paso paso_reglas

    if [ "$DRY_RUN" = "si" ]; then
        nota paso_reglas_dry
        return 0
    fi

    if git rev-parse --git-dir >/dev/null 2>&1 && [ -n "$(git ls-files -- CLAUDE.md 2>/dev/null)" ]; then
        git mv CLAUDE.md AGENTS.md
    else
        mv CLAUDE.md AGENTS.md
    fi
    ok paso_reglas_ok
}

paso_boost() {
    [ "$HAY_BOOST" = "si" ] || return 0

    paso paso_boost

    if [ "$DRY_RUN" = "si" ]; then
        nota paso_boost_dry_1
        nota paso_boost_dry_2
        return 0
    fi

    if [ -f config/boost.php ]; then
        aviso paso_boost_existe
    else
        mkdir -p config
        decir boost_config_php > config/boost.php
        ok paso_boost_creado
    fi

    if [ -f boost.json ]; then
        php -r "$(decir boost_json_php)" \
            && ok paso_boost_mcp
    fi

    respaldar ".claude" motivo_boost

    if php artisan boost:update --no-interaction >/dev/null 2>&1; then
        ok paso_boost_update_ok
    else
        aviso paso_boost_update_falla
    fi
}

paso_skills() {
    paso paso_skills

    if [ "$DRY_RUN" = "si" ]; then
        for carpeta in $FUENTES_SKILLS; do
            cantidad="$(contar_skills "$carpeta")"
            [ "$cantidad" = "0" ] && continue
            asistente="$(asistente_de_carpeta "$carpeta")"
            if necesita_enlace "$asistente" && ! esta_en_asistentes "$asistente"; then
                nota paso_skills_dry_dejar "$cantidad" "$carpeta"
                nota paso_skills_dry_dejar_2 "$asistente"
            else
                nota paso_skills_dry_mover "$cantidad" "$carpeta"
            fi
        done
        if [ "$HAY_CLAUDE_DIR" = "si" ]; then
            nota paso_skills_dry_claude
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
                aviso paso_skills_ciego "$carpeta" "$asistente"
                nota paso_skills_ciego_2 "$asistente"
            fi
            continue
        fi

        for origen in "$carpeta"/*/; do
            [ -d "$origen" ] || continue
            nombre="$(basename "$origen")"
            if [ -e ".agents/skills/$nombre" ]; then
                aviso paso_skills_pisado "$nombre" "$carpeta"
                continue
            fi
            mkdir -p .agents/skills
            mv "$origen" ".agents/skills/$nombre"
            ok paso_skills_movido "$nombre" "$carpeta"
            movidos=$((movidos + 1))
        done
    done

    if [ "$movidos" = "0" ] && [ "$HAY_CLAUDE_DIR" = "no" ]; then
        nota paso_skills_nada
    fi

    # Claude Code sí se respalda entero: este proyecto no lo usa, y sus comandos
    # y agentes propios no aplican. Queda recuperable en .agentes-respaldo/.
    if [ "$HAY_CLAUDE_DIR" = "si" ]; then
        quedan="$(find .claude -mindepth 1 -maxdepth 1 ! -name skills 2>/dev/null | sed 's|^\.claude/||' | tr '\n' ' ')"
        if [ -n "$quedan" ]; then
            aviso paso_skills_extra "$quedan"
        fi
        respaldar ".claude" motivo_claude
    fi
}

paso_enlaces() {
    if [ -z "$ASISTENTES" ]; then
        paso paso_enlaces
        nota plan_sin_enlaces_generico
        return 0
    fi

    paso paso_enlaces

    if [ "$DRY_RUN" = "si" ]; then
        # En simulación .agents/skills puede no existir aún: se cuenta lo que
        # quedaría ahí después de mover los skills.
        previstos="$(skills_previstos)"
        if [ "$previstos" = "0" ]; then
            nota paso_enlaces_dry_nada
        else
            for asistente in $ASISTENTES; do
                nota paso_enlaces_dry_crear "$previstos" "$(carpeta_asistente "$asistente")"
            done
        fi
        return 0
    fi

    if [ ! -d .agents/skills ]; then
        aviso paso_enlaces_sin_carpeta
        nota paso_enlaces_sin_carpeta_2
        return 0
    fi

    # Sin skills no se crea ni la carpeta del asistente. Una carpeta de enlaces
    # vacía no sirve de nada, y encima haría que la próxima corrida creyera que
    # el proyecto ya usa ese asistente (se detectan por su carpeta).
    if [ "$(contar_skills .agents/skills)" = "0" ]; then
        aviso paso_enlaces_vacio
        nota paso_enlaces_vacio_2
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
                aviso paso_enlaces_pisado "$nombre" "$destino"
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
            ok paso_enlaces_ok "$asistente" "$enlazados" "$destino"
        fi
        if [ "$copiados" -gt 0 ]; then
            aviso paso_enlaces_copiados "$asistente" "$copiados" "$destino"
            nota paso_enlaces_copiados_2
        fi
        ENLACES_HECHOS=$((ENLACES_HECHOS + enlazados + copiados))
    done
}

paso_mcp() {
    [ "$HAY_MCP" = "si" ] || return 0

    paso paso_mcp

    nota paso_mcp_nota_1
    nota paso_mcp_nota_2

    if preguntar paso_mcp_pregunta si; then
        ok paso_mcp_ok
    else
        respaldar ".mcp.json" motivo_mcp
    fi
}

migrar_leeme() {
    # El mismo archivo tuvo dos nombres antes: la 1.2.1 lo dejó en
    # .agents/skills/ (donde cualquier .md suelto cuenta como skill) y la 1.2.2
    # como .agents/LEEME.md. El nombre en inglés es la convención del resto
    # (AGENTS.md, README.md), así que se renombra: nada se pisa ni se borra.
    for viejo_leeme in ".agents/skills/LEEME.md" ".agents/LEEME.md"; do
        [ -f "$viejo_leeme" ] || continue

        # Solo si es el nuestro: alguien puede tener un archivo con ese nombre.
        # Los que dejaron esas versiones estaban en español, así que el
        # encabezado se busca en español aunque el idioma sea otro.
        if [ "$(head -1 "$viejo_leeme" 2>/dev/null)" != "# Skills de este proyecto" ]; then
            continue
        fi

        if [ -e .agents/README.md ]; then
            # Ya hay uno bueno. El viejo igual no puede quedarse dentro de la
            # raíz de skills, así que se guarda en el respaldo.
            respaldar "$viejo_leeme" motivo_leeme
            continue
        fi

        mv "$viejo_leeme" .agents/README.md
        ok migrar_leeme_ok "$viejo_leeme"
    done
}

paso_sembrar() {
    paso paso_sembrar

    if [ "$DRY_RUN" = "si" ]; then
        nota paso_sembrar_dry
        if [ -f .agents/skills/LEEME.md ] || [ -f .agents/LEEME.md ]; then
            nota paso_sembrar_dry_leeme
        fi
        return 0
    fi

    if [ ! -f AGENTS.md ]; then
        decir agents_md > AGENTS.md
        printf '%s\n' "$(frase_skills)" >> AGENTS.md
        decir agents_md_cierre >> AGENTS.md
        ok paso_sembrar_agents_ok
    fi

    migrar_leeme

    if [ ! -d .agents/skills ]; then
        mkdir -p .agents/skills
        ok paso_sembrar_skills_ok
    fi

    # El README va fuera de .agents/skills a propósito: ahí dentro, cualquier .md
    # suelto cuenta como skill de un solo archivo, y este no lo es (los
    # asistentes avisan de que le falta el frontmatter en cada sesión).
    if [ ! -f .agents/README.md ]; then
        decir agents_readme > .agents/README.md
        printf '%s\n' "$(frase_skills)" >> .agents/README.md
        ok paso_sembrar_readme_ok
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
        ok verificacion_ok "$1" "$2"
    else
        falla verificacion_falla "$1" "$2" "$3"
        FALLOS=$((FALLOS + 1))
    fi
}

estado_archivo() { [ -f "$1" ] && decir presente || decir ausente; }
estado_carpeta() { [ -d "$1" ] && decir presente || decir ausente; }

verificar() {
    paso verificar

    comprobar "AGENTS.md" "$(estado_archivo AGENTS.md)" "$(decir presente)"
    comprobar ".agents/skills" "$(estado_carpeta .agents/skills)" "$(decir presente)"
    comprobar "CLAUDE.md" "$(estado_archivo CLAUDE.md)" "$(decir ausente)"
    comprobar ".claude/" "$(estado_carpeta .claude)" "$(decir ausente)"

    esperados="$(contar_skills .agents/skills)"

    if [ -z "$ASISTENTES" ]; then
        nota verificar_sin_enlaces
    else
        for asistente in $ASISTENTES; do
            destino="$(carpeta_asistente "$asistente")"

            # Sin skills no hay enlaces que revisar... salvo que hayan quedado
            # enlaces viejos: esos sí, porque pueden estar rotos.
            if [ "$esperados" = "0" ] && [ "$(contar_skills "$destino")" = "0" ]; then
                nota verificar_sin_skills "$asistente"
                continue
            fi

            comprobar "$asistente: $(decir verificar_enlaces "$destino")" "$(contar_skills "$destino")" "$esperados"

            rotos=0
            for enlace in "$destino"/*; do
                # Se recorren todos los elementos (no solo directorios) porque un
                # enlace quebrado deja de ser un directorio y hay que verlo igual.
                [ -L "$enlace" ] || continue
                [ -e "$enlace" ] || rotos=$((rotos + 1))
            done

            if [ "$rotos" -gt 0 ]; then
                falla verificar_rotos "$asistente" "$rotos"
                FALLOS=$((FALLOS + 1))
            else
                ok verificar_resuelven "$asistente"
            fi
        done
    fi
}

resumen() {
    printf '\n%s────────────────────────────────────────────────────────────%s\n' "$GRIS" "$FIN"

    if [ "$FALLOS" -gt 0 ]; then
        printf '\n  %s%s%s\n\n' "$ERROR" "$(decir resumen_fallos "$FALLOS")" "$FIN"
        exit 1
    fi

    if [ "$DRY_RUN" = "si" ]; then
        printf '\n  %s%s%s\n' "$OK" "$(decir resumen_dry)" "$FIN"
        printf '  %s\n\n' "$(decir resumen_dry_2)"
        exit 0
    fi

    printf '\n  %s%s%s\n\n' "$OK" "$(decir resumen_listo)" "$FIN"

    # El cierre es general a propósito: nombra asistentes como ejemplo, nunca
    # como la lista de los que funcionan.
    printf '  %s\n' "$(decir resumen_estandar_1)"
    printf '  %s\n' "$(decir resumen_estandar_2)"
    printf '  %s\n\n' "$(decir resumen_estandar_3)"

    if [ -n "$ASISTENTES" ] && [ "$ENLACES_HECHOS" -gt 0 ]; then
        for asistente in $ASISTENTES; do
            decir resumen_enlace_creado "$asistente" "$(carpeta_asistente "$asistente")"
        done
        printf '\n'
    elif [ -n "$ASISTENTES" ]; then
        printf '  %s\n' "$(decir resumen_sin_enlaces_1)"
        printf '  %s\n\n' "$(decir resumen_sin_enlaces_2)"
    else
        printf '  %s\n' "$(decir resumen_no_creados)"
        printf '    %s\n\n' "$(decir resumen_no_creados_2)"
    fi

    if [ "$RESPALDADOS" -gt 0 ]; then
        printf '  %s%s%s\n' "$AVISO" "$(decir resumen_respaldo "$RESPALDADOS" "$RESPALDO")" "$FIN"
        printf '  %s\n\n' "$(decir resumen_respaldo_2)"
    fi

    if git rev-parse --git-dir >/dev/null 2>&1; then
        printf '  %s\n' "$(decir resumen_git_1)"
        printf '  %s\n\n' "$(decir resumen_git_2)"
    else
        printf '  %s\n' "$(decir resumen_sin_git)"
        printf '    %s\n\n' "$(decir resumen_sin_git_2)"
    fi
}

# ---------------------------------------------------------------------------
# Modo crear: corre el comando de creación y adapta lo que aparezca
# ---------------------------------------------------------------------------
crear_proyecto() {
    # "$@" = el comando de creación, tal cual lo escribió el usuario.
    banner
    decir crear_proyecto "$(pwd)"
    decir crear_comando "$*"

    if [ "$DRY_RUN" = "si" ]; then
        printf '\n  %s%s\n' "$AVISO" "$(decir crear_dry_1)"
        printf '  %s%s\n' "$(decir crear_dry_2)" "$FIN"
        printf '  %s\n\n' "$(decir crear_dry_3)"
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
        falla crear_fallo "$codigo"
        printf '  %s\n\n' "$(decir crear_fallo_2)"
        exit 1
    fi

    despues="$(ls -A1 2>/dev/null | sort)"
    nuevos="$(comm -13 <(printf '%s\n' "$antes") <(printf '%s\n' "$despues") | grep -v '^$' || true)"

    cuantos=0
    for elemento in $nuevos; do
        cuantos=$((cuantos + 1))
    done

    if [ "$cuantos" = "0" ]; then
        aviso crear_sin_carpeta
        nota crear_sin_carpeta_2
        nota crear_sin_carpeta_3
        printf '\n'
        exit 2
    fi

    if [ "$cuantos" -gt 1 ]; then
        aviso crear_varios
        for elemento in $nuevos; do
            dato "  $elemento"
        done
        printf '\n  %s\n\n' "$(decir crear_varios_2)"
        exit 2
    fi

    if [ ! -d "$nuevos" ]; then
        falla crear_no_carpeta "$nuevos"
        printf '\n'
        exit 2
    fi

    cd "$nuevos"
    ok crear_ok "$nuevos"

    # DSH busca la raíz del proyecto subiendo hasta encontrar .git. Sin repo
    # funciona igual mientras se abra en la carpeta exacta, pero no desde una
    # subcarpeta. Por eso se ofrece, nunca se hace solo.
    if [ ! -d .git ]; then
        if preguntar crear_git_pregunta si; then
            if git init -q . 2>/dev/null; then
                ok crear_git_ok
            else
                aviso crear_git_falla
            fi
        fi
    fi
}

# ---------------------------------------------------------------------------
# Los mensajes
#
# Un catálogo por idioma, con las mismas claves, y una plantilla aparte para los
# textos largos (la ayuda y los archivos que sembramos). Las claves con datos
# reciben sus valores como argumentos: `decir plan_enlaces_crear "$ruta"`.
# ---------------------------------------------------------------------------
mensaje_es() {
    case "$1" in
        # --- presentación ---------------------------------------------------
        banner_linea)                printf '  %sTrawün%s · convenciones de agentes · v%s\n' "$GRIS" "$FIN" "$2" ;;
        idioma_desconocido)          printf 'Idioma desconocido: %s' "$2" ;;
        idioma_conocidos)            printf 'Idiomas: es, en' ;;
        pregunta_sufijo)             printf ' [s/n] ' ;;
        pregunta_sin_terminal)       printf 'Sin terminal interactiva: uso la opción por defecto (%s).' "$2" ;;
        defecto_si)                  printf 'sí' ;;
        defecto_no)                  printf 'no' ;;
        confirmar_modo_si)           printf 'Modo --si: se aplica el plan sin preguntar.' ;;
        confirmar_sin_terminal)      printf 'No hay terminal para pedirte confirmación, así que no toco nada.' ;;
        confirmar_sin_terminal_2)    printf 'Si de verdad quieres aplicarlo sin preguntas: vuelve a correrlo con --si' ;;
        confirmar_pregunta)          printf '¿Aplico estos cambios?' ;;
        confirmar_cancelado)         printf 'Cancelado. No se tocó nada.' ;;

        # --- errores de argumentos ------------------------------------------
        error_opcion)                printf 'Opción desconocida: %s' "$2" ;;
        error_falta_valor)           printf 'Falta el valor de %s.' "$2" ;;
        error_falta_comando)         printf 'Falta el comando de creación.' ;;
        error_falta_comando_2)       printf 'Ejemplo: trawun y cargo new mi-proyecto' ;;
        error_carpeta)               printf 'No existe la carpeta: %s' "$2" ;;
        error_enlaces_contradiccion) printf 'No combines --asistentes con --sin-enlaces.' ;;

        # --- asistentes ------------------------------------------------------
        asistente_detectados)        printf '\n  %sDetecté instalado:%s %s\n' "$TITULO" "$FIN" "$2" ;;
        asistente_nota_1)            printf 'los enlaces solo hacen falta para asistentes con carpeta propia' ;;
        asistente_nota_2)            printf 'la mayoría de los asistentes lee .agents/skills directamente' ;;
        asistente_pregunta)          printf '¿Creo los enlaces para %s?' "$2" ;;
        asistente_desconocido)       printf 'Asistente desconocido: %s' "$2" ;;
        asistente_conocidos)         printf 'Conocidos: %s' "$2" ;;

        # --- plan ------------------------------------------------------------
        plan_proyecto)               printf '\n  Proyecto: %s%s%s\n' "$TITULO" "$2" "$FIN" ;;
        plan_encontre)               printf '\n  %sEncontré esto:%s\n' "$TITULO" "$FIN" ;;
        plan_tiene_claude_md)        printf 'CLAUDE.md (reglas para Claude Code)' ;;
        plan_sin_claude_md)          printf 'sin CLAUDE.md' ;;
        plan_tiene_claude_dir)       printf '.claude/ (%s skills de Claude Code)' "$2" ;;
        plan_sin_claude_dir)         printf 'sin .claude/' ;;
        plan_tiene_mcp)              printf '.mcp.json (servidores MCP)' ;;
        plan_sin_mcp)                printf 'sin .mcp.json' ;;
        plan_tiene_agents_md)        printf 'AGENTS.md (ya está en el nombre neutral)' ;;
        plan_tiene_agents_skills)    printf '.agents/skills (%s skills)' "$2" ;;
        plan_cursor)                 printf '.cursor/ (usa Cursor: lee .agents/skills, no necesita enlaces)' ;;
        plan_boost)                  printf 'Laravel Boost (genera guías y skills)' ;;
        plan_hare)                   printf '\n  %sLo que voy a hacer:%s\n' "$TITULO" "$FIN" ;;
        plan_mover_reglas)           printf 'Mover CLAUDE.md  ->  AGENTS.md' ;;
        plan_dos_reglas)             printf 'Existen CLAUDE.md y AGENTS.md: los reviso pero NO los toco (hay que unirlos a mano)' ;;
        plan_boost_hacer)            printf 'Redirigir Boost a las rutas neutrales y apagar su MCP' ;;
        plan_skills_ya)              printf 'Los skills de %s ya están en .agents/skills: nada que mover' "$2" ;;
        plan_skills_dejar)           printf 'Dejar los skills de %s donde están (%s no lee la ruta neutral)' "$2" "$3" ;;
        plan_skills_mover)           printf 'Mover los skills de %s  ->  .agents/skills' "$2" ;;
        plan_respaldar_claude)       printf 'Respaldar .claude/ en .agentes-respaldo/ (no usas Claude Code)' ;;
        plan_enlaces_nada)           printf 'Enlaces de asistente: no hay skills todavía, no hay nada que enlazar' ;;
        plan_enlaces_crear)          printf 'Crear los enlaces de %s hacia .agents/skills' "$2" ;;
        plan_sin_enlaces)            printf 'sin enlaces de asistente (solo AGENTS.md y .agents/skills)' ;;
        plan_sin_enlaces_generico)   printf 'ninguno: la mayoría de los asistentes lee .agents/skills directo' ;;
        plan_sembrar)                printf 'Crear un AGENTS.md inicial para que lo completes' ;;
        plan_mcp_pregunta)           printf '.mcp.json: te pregunto aparte si lo conservo (Qoder sí lo lee)' ;;
        plan_nada_se_borra)          printf 'Nada se borra: lo que sobra va a .agentes-respaldo/' ;;
        plan_no_escribo)             printf 'No escribo fuera de este proyecto ni instalo nada global.' ;;
        dry_run_banda)               printf '── modo dry-run: no se toca ningún archivo ──' ;;
        dry_run_verificar)           printf '[dry-run] no hay nada que verificar' ;;

        # --- frases de los archivos sembrados --------------------------------
        frase_con_enlaces)           printf 'Los skills de este proyecto viven en `.agents/skills/`, con enlaces en %s.' "$2" ;;
        frase_sin_enlaces)           printf 'Los skills de este proyecto viven en `.agents/skills/`; los asistentes\nque leen esa ruta los ven sin configurar nada más.' ;;

        # --- respaldo --------------------------------------------------------
        respaldo_dry)                printf '[dry-run] movería %s a %s/' "$2" "$3" ;;
        respaldo_hecho)              printf '%s  ->  %s/  (%s)' "$2" "$3" "$4" ;;
        motivo_boost)                printf 'Boost lo regenera en .agents/skills' ;;
        motivo_claude)               printf 'configuración de Claude Code' ;;
        motivo_mcp)                  printf 'no lo quieres usar por ahora' ;;
        motivo_leeme)                printf 'quedó viejo: ya existe .agents/README.md' ;;

        # --- pasos -----------------------------------------------------------
        paso_reglas)                 printf 'Reglas: CLAUDE.md -> AGENTS.md' ;;
        paso_reglas_dry)             printf '[dry-run] renombraría CLAUDE.md a AGENTS.md' ;;
        paso_reglas_ok)              printf 'AGENTS.md listo (mismo contenido, nombre que sí lee la mayoría de los asistentes)' ;;
        paso_boost)                  printf 'Laravel Boost: redirigir sus rutas' ;;
        paso_boost_dry_1)            printf '[dry-run] escribiría config/boost.php y pondría "mcp": false en boost.json' ;;
        paso_boost_dry_2)            printf '[dry-run] correría: php artisan boost:update' ;;
        paso_boost_existe)           printf 'config/boost.php ya existe: no lo toco, revísalo a mano' ;;
        paso_boost_creado)           printf 'config/boost.php creado' ;;
        paso_boost_mcp)              printf 'boost.json: MCP apagado (nada de herramientas fantasma en las guías)' ;;
        paso_boost_update_ok)        printf 'boost:update corrido: guías y skills reescritos en las rutas nuevas' ;;
        paso_boost_update_falla)     printf 'boost:update falló; córrelo a mano: php artisan boost:update' ;;
        paso_skills)                 printf 'Skills de cada asistente' ;;
        paso_skills_dry_dejar)       printf '[dry-run] dejaría %s skill(s) en %s' "$2" "$3" ;;
        paso_skills_dry_dejar_2)     printf '  (%s no lee .agents/skills; moverlos sin enlace lo dejaría ciego)' "$2" ;;
        paso_skills_dry_mover)       printf '[dry-run] movería %s skill(s) de %s a .agents/skills' "$2" "$3" ;;
        paso_skills_dry_claude)      printf '[dry-run] movería .claude/ a .agentes-respaldo/' ;;
        paso_skills_ciego)           printf '%s tiene skills y %s no lee .agents/skills' "$2" "$3" ;;
        paso_skills_ciego_2)         printf 'los dejo donde están; para unificarlos: trawun --asistentes %s' "$2" ;;
        paso_skills_pisado)          printf '%s ya existe en .agents/skills: no lo piso (venía de %s)' "$2" "$3" ;;
        paso_skills_movido)          printf '%s  (%s -> .agents/skills)' "$2" "$3" ;;
        paso_skills_nada)            printf 'no encontré skills que mover' ;;
        paso_skills_extra)           printf 'además va al respaldo, y no son skills: %s' "$2" ;;
        paso_enlaces)                printf 'Enlaces de asistentes' ;;
        paso_enlaces_dry_nada)       printf '[dry-run] no crearía enlaces: todavía no hay skills' ;;
        paso_enlaces_dry_crear)      printf '[dry-run] crearía %s enlace(s) en %s' "$2" "$3" ;;
        paso_enlaces_sin_carpeta)    printf 'No hay .agents/skills todavía: no hay nada que enlazar' ;;
        paso_enlaces_sin_carpeta_2)  printf 'Cuando agregues skills ahí, vuelve a correr Trawün.' ;;
        paso_enlaces_vacio)          printf 'Todavía no hay skills en .agents/skills: no hay nada que enlazar' ;;
        paso_enlaces_vacio_2)        printf 'Cuando agregues alguno, vuelve a correr Trawün.' ;;
        paso_enlaces_pisado)         printf '%s ya existe en %s como carpeta real: no lo toco' "$2" "$3" ;;
        paso_enlaces_ok)             printf '%s: %s enlace(s) en %s' "$2" "$3" "$4" ;;
        paso_enlaces_copiados)       printf '%s: %s copia(s) en %s (este sistema no permite enlaces)' "$2" "$3" "$4" ;;
        paso_enlaces_copiados_2)     printf 'si cambias esos skills, vuelve a correr Trawün' ;;
        paso_mcp)                    printf 'Servidores MCP (.mcp.json)' ;;
        paso_mcp_nota_1)             printf 'Qoder SÍ lee .mcp.json de este proyecto; los demás asistentes tienen su propia forma de configurar MCP.' ;;
        paso_mcp_nota_2)             printf 'Cada servidor MCP suma sus herramientas a cada mensaje que envíes.' ;;
        paso_mcp_pregunta)           printf '¿Conservo .mcp.json?' ;;
        paso_mcp_ok)                 printf 'Se conserva: revisa que los servidores que declara sean los que quieres' ;;
        paso_sembrar)                printf 'Lo que faltaba por crear' ;;
        paso_sembrar_dry)            printf '[dry-run] crearía AGENTS.md, .agents/skills y .agents/README.md si faltan' ;;
        paso_sembrar_dry_leeme)      printf '[dry-run] renombraría el LEEME que dejaron versiones anteriores' ;;
        paso_sembrar_agents_ok)      printf 'AGENTS.md creado (con secciones para completar)' ;;
        paso_sembrar_skills_ok)      printf '.agents/skills/ creado' ;;
        paso_sembrar_readme_ok)      printf '.agents/README.md creado (explica la convención, fuera de la raíz de skills)' ;;
        migrar_leeme_ok)             printf '%s  ->  .agents/README.md (nombre en inglés, como el resto)' "$2" ;;
        agents_md_cierre)            printf 'Los skills son de este proyecto y de ningún otro: no se instalan de\nforma global.' ;;

        # --- verificación -----------------------------------------------------
        verificar)                   printf 'Verificación' ;;
        presente)                    printf 'presente' ;;
        ausente)                     printf 'ausente' ;;
        verificacion_ok)             printf '%s: %s' "$2" "$3" ;;
        verificacion_falla)          printf '%s: %s (esperaba %s)' "$2" "$3" "$4" ;;
        verificar_sin_enlaces)       printf 'sin enlaces de asistente: no hay nada que revisar aquí' ;;
        verificar_sin_skills)        printf '%s: todavía no hay skills, no hay enlaces que revisar' "$2" ;;
        verificar_enlaces)           printf 'enlaces en %s' "$2" ;;
        verificar_rotos)             printf '%s: %s enlace(s) roto(s)' "$2" "$3" ;;
        verificar_resuelven)         printf '%s: todos los enlaces resuelven' "$2" ;;

        # --- resumen ----------------------------------------------------------
        resumen_fallos)              printf 'Quedaron %s problema(s). Revisa arriba.' "$2" ;;
        resumen_dry)                 printf 'Simulación terminada. No se tocó nada.' ;;
        resumen_dry_2)               printf 'Corre sin --dry-run para aplicarlo.' ;;
        resumen_listo)               printf 'Listo.' ;;
        resumen_estandar_1)          printf 'Este proyecto ya está en el estándar neutral: las reglas en AGENTS.md y' ;;
        resumen_estandar_2)          printf 'los skills en .agents/skills/. Lo ve cualquier asistente que respete esas' ;;
        resumen_estandar_3)          printf 'rutas —DSH, Codex, Cursor, Zed, entre otros— sin configurar nada más.' ;;
        resumen_enlace_creado)       printf '  Enlaces creados para %s%s%s en %s\n' "$TITULO" "$2" "$FIN" "$3" ;;
        resumen_sin_enlaces_1)       printf 'Todavía no hay skills en .agents/skills, así que no creé enlaces.' ;;
        resumen_sin_enlaces_2)       printf 'Cuando agregues alguno, vuelve a correr Trawün y los crea.' ;;
        resumen_no_creados)          printf 'No creé enlaces de asistente. Si usas Qoder o Copilot:' ;;
        resumen_no_creados_2)        printf 'trawun --asistentes qoder,copilot' ;;
        resumen_respaldo)            printf 'Respaldé %s cosa(s) en %s/' "$2" "$3" ;;
        resumen_respaldo_2)          printf 'Si todo anda bien, borra esa carpeta.' ;;
        resumen_git_1)               printf '1. Revisa el diff:   git status && git diff' ;;
        resumen_git_2)               printf '2. Commitea:         git add -A && git commit -m "chore: convenciones de agentes"' ;;
        resumen_sin_git)             printf 'Este proyecto todavía no es un repositorio git. Si quieres versionarlo:' ;;
        resumen_sin_git_2)           printf 'git init && git add -A && git commit -m "chore: convenciones de agentes"' ;;

        # --- modo crear --------------------------------------------------------
        crear_proyecto)              printf '\n  Proyecto nuevo en: %s%s%s\n' "$TITULO" "$2" "$FIN" ;;
        crear_comando)               printf '  Comando: %s%s%s\n' "$TITULO" "$2" "$FIN" ;;
        crear_dry_1)                 printf 'En simulación no puedo mostrarte el plan: todavía no existe el' ;;
        crear_dry_2)                 printf 'proyecto, y crearlo es justamente lo que la simulación evita.' ;;
        crear_dry_3)                 printf 'Corre el comando sin -n cuando quieras hacerlo de verdad.' ;;
        crear_fallo)                 printf 'el comando de creación falló (código %s)' "$2" ;;
        crear_fallo_2)               printf 'No adapto nada. Revisa el error de arriba.' ;;
        crear_sin_carpeta)           printf 'El comando no creó ninguna carpeta nueva.' ;;
        crear_sin_carpeta_2)         printf 'Si escribió aquí mismo (cargo init, npm init), entra a la carpeta' ;;
        crear_sin_carpeta_3)         printf 'del proyecto y corre trawun ahí.' ;;
        crear_varios)                printf 'Aparecieron varios elementos nuevos:' ;;
        crear_varios_2)              printf 'Entra a la carpeta del proyecto y corre trawun ahí.' ;;
        crear_no_carpeta)            printf 'lo que apareció no es una carpeta: %s' "$2" ;;
        crear_ok)                    printf 'proyecto creado: %s' "$2" ;;
        crear_git_pregunta)          printf '¿Inicializo un repositorio git? (ayuda a ubicar la raíz)' ;;
        crear_git_ok)                printf 'repositorio git iniciado' ;;
        crear_git_falla)             printf 'no pude iniciar el repositorio (¿está instalado git?)' ;;

        # --- textos largos -----------------------------------------------------
        ayuda)                       plantilla_ayuda_es ;;
        agents_md)                   plantilla_agents_md_es ;;
        agents_readme)               plantilla_agents_readme_es ;;
        respaldo_txt)                plantilla_respaldo_txt_es "$2" ;;
        boost_config_php)            plantilla_boost_config_es ;;
        boost_json_php)              plantilla_boost_json_es ;;

        *)                           printf 'FALTA TEXTO (es): %s' "$1" >&2 ;;
    esac
}

mensaje_en() {
    case "$1" in
        # --- presentation -----------------------------------------------------
        banner_linea)                printf '  %sTrawün%s · agent conventions · v%s\n' "$GRIS" "$FIN" "$2" ;;
        idioma_desconocido)          printf 'Unknown language: %s' "$2" ;;
        idioma_conocidos)            printf 'Languages: es, en' ;;
        pregunta_sufijo)             printf ' [y/n] ' ;;
        pregunta_sin_terminal)       printf 'No interactive terminal: using the default (%s).' "$2" ;;
        defecto_si)                  printf 'yes' ;;
        defecto_no)                  printf 'no' ;;
        confirmar_modo_si)           printf 'Yes mode (--yes): the plan is applied without asking.' ;;
        confirmar_sin_terminal)      printf 'There is no terminal to ask you for confirmation, so I touch nothing.' ;;
        confirmar_sin_terminal_2)    printf 'If you really want it applied without questions: run it again with --yes' ;;
        confirmar_pregunta)          printf 'Apply these changes?' ;;
        confirmar_cancelado)         printf 'Cancelled. Nothing was touched.' ;;

        # --- argument errors ---------------------------------------------------
        error_opcion)                printf 'Unknown option: %s' "$2" ;;
        error_falta_valor)           printf 'Missing the value of %s.' "$2" ;;
        error_falta_comando)         printf 'The creation command is missing.' ;;
        error_falta_comando_2)       printf 'Example: trawun y cargo new my-project' ;;
        error_carpeta)               printf 'No such folder: %s' "$2" ;;
        error_enlaces_contradiccion) printf 'Do not combine --assistants with --no-links.' ;;

        # --- assistants ---------------------------------------------------------
        asistente_detectados)        printf '\n  %sFound installed:%s %s\n' "$TITULO" "$FIN" "$2" ;;
        asistente_nota_1)            printf 'links are only needed by assistants with a folder of their own' ;;
        asistente_nota_2)            printf 'most assistants read .agents/skills directly' ;;
        asistente_pregunta)          printf 'Create the links for %s?' "$2" ;;
        asistente_desconocido)       printf 'Unknown assistant: %s' "$2" ;;
        asistente_conocidos)         printf 'Known: %s' "$2" ;;

        # --- plan ---------------------------------------------------------------
        plan_proyecto)               printf '\n  Project: %s%s%s\n' "$TITULO" "$2" "$FIN" ;;
        plan_encontre)               printf '\n  %sI found this:%s\n' "$TITULO" "$FIN" ;;
        plan_tiene_claude_md)        printf 'CLAUDE.md (Claude Code rules)' ;;
        plan_sin_claude_md)          printf 'no CLAUDE.md' ;;
        plan_tiene_claude_dir)       printf '.claude/ (%s Claude Code skill(s))' "$2" ;;
        plan_sin_claude_dir)         printf 'no .claude/' ;;
        plan_tiene_mcp)              printf '.mcp.json (MCP servers)' ;;
        plan_sin_mcp)                printf 'no .mcp.json' ;;
        plan_tiene_agents_md)        printf 'AGENTS.md (already under the neutral name)' ;;
        plan_tiene_agents_skills)    printf '.agents/skills (%s skills)' "$2" ;;
        plan_cursor)                 printf '.cursor/ (Cursor is used: it reads .agents/skills, no links needed)' ;;
        plan_boost)                  printf 'Laravel Boost (writes guidelines and skills)' ;;
        plan_hare)                   printf '\n  %sWhat I am going to do:%s\n' "$TITULO" "$FIN" ;;
        plan_mover_reglas)           printf 'Move CLAUDE.md  ->  AGENTS.md' ;;
        plan_dos_reglas)             printf 'Both CLAUDE.md and AGENTS.md exist: I review them but do NOT touch them (they must be merged by hand)' ;;
        plan_boost_hacer)            printf 'Point Boost at the neutral paths and turn its MCP off' ;;
        plan_skills_ya)              printf 'The skills in %s are already in .agents/skills: nothing to move' "$2" ;;
        plan_skills_dejar)           printf 'Leave the skills in %s where they are (%s does not read the neutral path)' "$2" "$3" ;;
        plan_skills_mover)           printf 'Move the skills in %s  ->  .agents/skills' "$2" ;;
        plan_respaldar_claude)       printf 'Back up .claude/ into .agentes-respaldo/ (you do not use Claude Code)' ;;
        plan_enlaces_nada)           printf 'Assistant links: there are no skills yet, nothing to link' ;;
        plan_enlaces_crear)          printf 'Create the links in %s towards .agents/skills' "$2" ;;
        plan_sin_enlaces)            printf 'no assistant links (AGENTS.md and .agents/skills only)' ;;
        plan_sin_enlaces_generico)   printf 'none: most assistants read .agents/skills directly' ;;
        plan_sembrar)                printf 'Create a starter AGENTS.md for you to fill in' ;;
        plan_mcp_pregunta)           printf '.mcp.json: I ask you separately whether to keep it (Qoder does read it)' ;;
        plan_nada_se_borra)          printf 'Nothing is deleted: leftovers move to .agentes-respaldo/' ;;
        plan_no_escribo)             printf 'I write nothing outside this project and install nothing globally.' ;;
        dry_run_banda)               printf '── dry-run mode: no file is touched ──' ;;
        dry_run_verificar)           printf '[dry-run] there is nothing to verify' ;;

        # --- phrases for the seeded files ---------------------------------------
        frase_con_enlaces)           printf 'The skills of this project live in `.agents/skills/`, with links in %s.' "$2" ;;
        frase_sin_enlaces)           printf 'The skills of this project live in `.agents/skills/`; the assistants\nthat read that path see them with nothing else to configure.' ;;

        # --- backup --------------------------------------------------------------
        respaldo_dry)                printf '[dry-run] would move %s to %s/' "$2" "$3" ;;
        respaldo_hecho)              printf '%s  ->  %s/  (%s)' "$2" "$3" "$4" ;;
        motivo_boost)                printf 'Boost recreates it in .agents/skills' ;;
        motivo_claude)               printf 'Claude Code configuration' ;;
        motivo_mcp)                  printf 'you do not want it for now' ;;
        motivo_leeme)                printf 'it went stale: .agents/README.md already exists' ;;

        # --- steps ----------------------------------------------------------------
        paso_reglas)                 printf 'Rules: CLAUDE.md -> AGENTS.md' ;;
        paso_reglas_dry)             printf '[dry-run] would rename CLAUDE.md to AGENTS.md' ;;
        paso_reglas_ok)              printf 'AGENTS.md is ready (same content, a name most assistants do read)' ;;
        paso_boost)                  printf 'Laravel Boost: redirect its paths' ;;
        paso_boost_dry_1)            printf '[dry-run] would write config/boost.php and set "mcp": false in boost.json' ;;
        paso_boost_dry_2)            printf '[dry-run] would run: php artisan boost:update' ;;
        paso_boost_existe)           printf 'config/boost.php already exists: I leave it alone, review it by hand' ;;
        paso_boost_creado)           printf 'config/boost.php created' ;;
        paso_boost_mcp)              printf 'boost.json: MCP off (no phantom tools in the guidelines)' ;;
        paso_boost_update_ok)        printf 'boost:update ran: guidelines and skills rewritten under the new paths' ;;
        paso_boost_update_falla)     printf 'boost:update failed; run it by hand: php artisan boost:update' ;;
        paso_skills)                 printf 'Skills of each assistant' ;;
        paso_skills_dry_dejar)       printf '[dry-run] would leave %s skill(s) in %s' "$2" "$3" ;;
        paso_skills_dry_dejar_2)     printf '  (%s does not read .agents/skills; moving them without a link would blind it)' "$2" ;;
        paso_skills_dry_mover)       printf '[dry-run] would move %s skill(s) from %s to .agents/skills' "$2" "$3" ;;
        paso_skills_dry_claude)      printf '[dry-run] would move .claude/ to .agentes-respaldo/' ;;
        paso_skills_ciego)           printf '%s has skills and %s does not read .agents/skills' "$2" "$3" ;;
        paso_skills_ciego_2)         printf 'I leave them where they are; to unify them: trawun --assistants %s' "$2" ;;
        paso_skills_pisado)          printf '%s already exists in .agents/skills: I do not overwrite it (it came from %s)' "$2" "$3" ;;
        paso_skills_movido)          printf '%s  (%s -> .agents/skills)' "$2" "$3" ;;
        paso_skills_nada)            printf 'I found no skills to move' ;;
        paso_skills_extra)           printf 'this also goes to the backup, and it is not skills: %s' "$2" ;;
        paso_enlaces)                printf 'Assistant links' ;;
        paso_enlaces_dry_nada)       printf '[dry-run] would create no links: there are no skills yet' ;;
        paso_enlaces_dry_crear)      printf '[dry-run] would create %s link(s) in %s' "$2" "$3" ;;
        paso_enlaces_sin_carpeta)    printf 'There is no .agents/skills yet: nothing to link' ;;
        paso_enlaces_sin_carpeta_2)  printf 'Once you add skills there, run Trawün again.' ;;
        paso_enlaces_vacio)          printf 'There are no skills in .agents/skills yet: nothing to link' ;;
        paso_enlaces_vacio_2)        printf 'Once you add one, run Trawün again.' ;;
        paso_enlaces_pisado)         printf '%s already exists in %s as a real folder: I leave it alone' "$2" "$3" ;;
        paso_enlaces_ok)             printf '%s: %s link(s) in %s' "$2" "$3" "$4" ;;
        paso_enlaces_copiados)       printf '%s: %s copy(ies) in %s (this system does not allow links)' "$2" "$3" "$4" ;;
        paso_enlaces_copiados_2)     printf 'if you change those skills, run Trawün again' ;;
        paso_mcp)                    printf 'MCP servers (.mcp.json)' ;;
        paso_mcp_nota_1)             printf 'Qoder does read .mcp.json from this project; other assistants have their own ways.' ;;
        paso_mcp_nota_2)             printf 'Every MCP server adds its tools to every message you send.' ;;
        paso_mcp_pregunta)           printf 'Keep .mcp.json?' ;;
        paso_mcp_ok)                 printf 'Kept: check that the servers it declares are the ones you want' ;;
        paso_sembrar)                printf 'What was missing' ;;
        paso_sembrar_dry)            printf '[dry-run] would create AGENTS.md, .agents/skills and .agents/README.md if missing' ;;
        paso_sembrar_dry_leeme)      printf '[dry-run] would rename the LEEME left by older versions' ;;
        paso_sembrar_agents_ok)      printf 'AGENTS.md created (with sections to fill in)' ;;
        paso_sembrar_skills_ok)      printf '.agents/skills/ created' ;;
        paso_sembrar_readme_ok)      printf '.agents/README.md created (explains the convention, outside the skills root)' ;;
        migrar_leeme_ok)             printf '%s  ->  .agents/README.md (English name, like the rest)' "$2" ;;
        agents_md_cierre)            printf 'The skills belong to this project and to no other: they are never\ninstalled globally.' ;;

        # --- verification -----------------------------------------------------------
        verificar)                   printf 'Verification' ;;
        presente)                    printf 'present' ;;
        ausente)                     printf 'absent' ;;
        verificacion_ok)             printf '%s: %s' "$2" "$3" ;;
        verificacion_falla)          printf '%s: %s (expected %s)' "$2" "$3" "$4" ;;
        verificar_sin_enlaces)       printf 'no assistant links: nothing to check here' ;;
        verificar_sin_skills)        printf '%s: no skills yet, no links to check' "$2" ;;
        verificar_enlaces)           printf 'links in %s' "$2" ;;
        verificar_rotos)             printf '%s: %s broken link(s)' "$2" "$3" ;;
        verificar_resuelven)         printf '%s: every link resolves' "$2" ;;

        # --- summary -----------------------------------------------------------------
        resumen_fallos)              printf '%s problem(s) left. Check above.' "$2" ;;
        resumen_dry)                 printf 'Dry run finished. Nothing was touched.' ;;
        resumen_dry_2)               printf 'Run it without --dry-run to apply it.' ;;
        resumen_listo)               printf 'Done.' ;;
        resumen_estandar_1)          printf 'This project is now on the neutral standard: the rules in AGENTS.md and' ;;
        resumen_estandar_2)          printf 'the skills in .agents/skills/. Any assistant that honours those paths' ;;
        resumen_estandar_3)          printf '—DSH, Codex, Cursor, Zed, among others— sees them with nothing to set up.' ;;
        resumen_enlace_creado)       printf '  Links created for %s%s%s in %s\n' "$TITULO" "$2" "$FIN" "$3" ;;
        resumen_sin_enlaces_1)       printf 'There are no skills in .agents/skills yet, so I created no links.' ;;
        resumen_sin_enlaces_2)       printf 'Once you add one, run Trawün again and it will create them.' ;;
        resumen_no_creados)          printf 'I created no assistant links. If you use Qoder or Copilot:' ;;
        resumen_no_creados_2)        printf 'trawun --assistants qoder,copilot' ;;
        resumen_respaldo)            printf 'Backed up %s thing(s) into %s/' "$2" "$3" ;;
        resumen_respaldo_2)          printf 'If everything works, delete that folder.' ;;
        resumen_git_1)               printf '1. Review the diff:  git status && git diff' ;;
        resumen_git_2)               printf '2. Commit:           git add -A && git commit -m "chore: agent conventions"' ;;
        resumen_sin_git)             printf 'This project is not a git repository yet. If you want to version it:' ;;
        resumen_sin_git_2)           printf 'git init && git add -A && git commit -m "chore: agent conventions"' ;;

        # --- create mode ----------------------------------------------------------------
        crear_proyecto)              printf '\n  New project in: %s%s%s\n' "$TITULO" "$2" "$FIN" ;;
        crear_comando)               printf '  Command: %s%s%s\n' "$TITULO" "$2" "$FIN" ;;
        crear_dry_1)                 printf 'In a dry run I cannot show you the plan: the project does not' ;;
        crear_dry_2)                 printf 'exist yet, and creating it is exactly what the dry run avoids.' ;;
        crear_dry_3)                 printf 'Run the command without -n when you want to do it for real.' ;;
        crear_fallo)                 printf 'the creation command failed (code %s)' "$2" ;;
        crear_fallo_2)               printf 'I adapt nothing. Check the error above.' ;;
        crear_sin_carpeta)           printf 'The command created no new folder.' ;;
        crear_sin_carpeta_2)         printf 'If it wrote right here (cargo init, npm init), step into the' ;;
        crear_sin_carpeta_3)         printf 'project folder and run trawun there.' ;;
        crear_varios)                printf 'Several new items showed up:' ;;
        crear_varios_2)              printf 'Step into the project folder and run trawun there.' ;;
        crear_no_carpeta)            printf 'what showed up is not a folder: %s' "$2" ;;
        crear_ok)                    printf 'project created: %s' "$2" ;;
        crear_git_pregunta)          printf 'Initialise a git repository? (it helps find the project root)' ;;
        crear_git_ok)                printf 'git repository initialised' ;;
        crear_git_falla)             printf 'I could not initialise the repository (is git installed?)' ;;

        # --- long texts ------------------------------------------------------------------
        ayuda)                       plantilla_ayuda_en ;;
        agents_md)                   plantilla_agents_md_en ;;
        agents_readme)               plantilla_agents_readme_en ;;
        respaldo_txt)                plantilla_respaldo_txt_en "$2" ;;
        boost_config_php)            plantilla_boost_config_en ;;
        boost_json_php)              plantilla_boost_json_en ;;

        *)                           printf 'MISSING TEXT (en): %s' "$1" >&2 ;;
    esac
}

# ---------------------------------------------------------------------------
# Plantillas: los textos de varias líneas, uno por idioma
# ---------------------------------------------------------------------------
plantilla_ayuda_es() {
    cat <<'AYUDA'

  Prepara un proyecto para los asistentes de IA que leen el estándar neutral:
  deja las reglas en AGENTS.md y los skills en .agents/skills.

  La mayoría de los asistentes lee esas rutas directamente y no necesita nada
  (DSH, Codex, Cursor, Zed, entre otros). Unos pocos usan carpeta propia y
  reciben enlaces: Qoder (.qoder/skills) y Copilot (.github/skills).

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
    -n, --dry-run          Muestra qué haría, sin tocar un solo archivo.
    -y, --si               Responde sí a todo. Útil para automatizar.
    -l, --idioma <es|en>   En qué idioma habla Trawün. También sirve la variable
                           TRAWUN_IDIOMA. Sin esto, usa el del sistema.
    --asistentes <lista>   Para qué asistentes crear enlaces, separados por
                           coma. Conocidos: qoder, copilot.
    --sin-enlaces          No crear enlaces de ningún asistente.
    -h, --ayuda            Muestra esta ayuda.
    -v, --version          Muestra la versión.

  Las opciones también tienen su nombre en inglés: --language, --yes,
  --assistants, --no-links y --help.

  Ejemplos:
    bash trawun.sh                          # adapta el proyecto actual
    bash trawun.sh -n                       # solo muestra el plan
    bash trawun.sh --asistentes qoder       # enlaces solo para Qoder
    bash trawun.sh --sin-enlaces            # sin enlaces de asistente
    bash trawun.sh y cargo new gestor       # crea el proyecto y lo adapta
AYUDA
}

plantilla_ayuda_en() {
    cat <<'AYUDA'

  Gets a project ready for the AI assistants that read the neutral standard:
  the rules in AGENTS.md and the skills in .agents/skills.

  Most assistants read those paths directly and need nothing at all (DSH,
  Codex, Cursor, Zed, among others). A few use a folder of their own and get
  links: Qoder (.qoder/skills) and Copilot (.github/skills).

  What it does, in order:
    1. Looks at what the project brings (CLAUDE.md, .claude/, .mcp.json, Boost…).
    2. Shows you the plan and asks for confirmation.
    3. Backs up what it will move into .agentes-respaldo/ (nothing is destroyed).
    4. Moves the rules to AGENTS.md and the skills to .agents/skills.
    5. If the project uses Laravel Boost, it is redirected so it stops recreating files.
    6. Creates the links the assistants in use need.
    7. Verifies the result and tells you what is left in your hands.

  What it does NOT do:
    · It does not write outside the project (your home folder is never touched).
    · It does not install skills globally.
    · It does not delete anything: leftovers move to .agentes-respaldo/.
    · It does not commit: at the end it shows you the diff and you decide.
    · It does not invent rules: whatever you already have is respected.

  Usage:
    bash trawun.sh [options] [path]         adapts a project that already exists
    bash trawun.sh [options] y <command>    creates a project and adapts it

  Options:
    -n, --dry-run           Shows what it would do, without touching a single file.
    -y, --yes               Answers yes to everything. Handy for automation.
    -l, --language <es|en>  Which language Trawün speaks. The TRAWUN_IDIOMA
                            variable works too. Without it, it uses the system
                            one.
    --assistants <list>     Which assistants get links, comma separated.
                            Known: qoder, copilot.
    --no-links              Creates no assistant links at all.
    -h, --help              Shows this help.
    -v, --version           Shows the version.

  The options also work with their Spanish names: --idioma, --si,
  --asistentes, --sin-enlaces and --ayuda.

  Examples:
    bash trawun.sh                          # adapts the current project
    bash trawun.sh -n                       # shows the plan only
    bash trawun.sh --assistants qoder       # links for Qoder only
    bash trawun.sh --no-links               # no assistant links
    bash trawun.sh y cargo new gestor       # creates the project and adapts it
AYUDA
}

plantilla_agents_md_es() {
    cat <<'MD'
# Reglas del proyecto

> Este archivo lo leen los asistentes de IA que trabajan con el estándar
> neutral (`AGENTS.md` y `.agents/skills/`), entre ellos DSH, Qoder, Codex,
> Cursor y Zed. Trawün lo creó vacío a propósito: escríbelo tú, con las reglas
> reales del proyecto. Un archivo corto y concreto rinde más que uno largo y
> genérico.

## Qué es este proyecto

(Pendiente: una o dos frases.)

## Cómo se trabaja aquí

- (Pendiente: comandos que se corren antes de dar algo por terminado.)
- (Pendiente: convenciones de nombres, idioma, formato.)

## Trampas conocidas

- (Pendiente: lo que ya te costó tiempo una vez.)

## Archivos para asistentes

MD
}

plantilla_agents_md_en() {
    cat <<'MD'
# Project rules

> This file is read by the AI assistants that work with the neutral standard
> (`AGENTS.md` and `.agents/skills/`), among them DSH, Qoder, Codex, Cursor
> and Zed. Trawün created it empty on purpose: write it yourself, with the
> real rules of the project. A short, concrete file goes further than a long,
> generic one.

## What this project is

(Pending: one or two sentences.)

## How work is done here

- (Pending: commands to run before calling something done.)
- (Pending: naming, language and formatting conventions.)

## Known traps

- (Pending: whatever already cost you time once.)

## Files for assistants

MD
}

plantilla_agents_readme_es() {
    cat <<'MD'
# Skills de este proyecto

Cada skill vive en su propia carpeta: `.agents/skills/<nombre>/SKILL.md`, con
frontmatter YAML que incluya `name` y `description`.

Los skills de este proyecto son de este proyecto. No se instalan de forma
global: si los pusieras en tu carpeta de usuario, aparecerían en todos los
demás proyectos tuyos, incluso donde no tienen nada que hacer.

MD
}

plantilla_agents_readme_en() {
    cat <<'MD'
# Skills for this project

Every skill lives in a folder of its own: `.agents/skills/<name>/SKILL.md`, with
YAML frontmatter that includes `name` and `description`.

The skills of this project belong to this project. They are never installed
globally: if you put them in your home folder they would show up in every other
project of yours, even where they have nothing to do.

MD
}

plantilla_respaldo_txt_es() {
    # $1 = fecha del respaldo
    printf 'Respaldo hecho por Trawün el %s\n\n' "$1"
    printf 'Aquí está lo que el proyecto traía para Claude Code y que Trawün\n'
    printf 'movió para dejar las rutas neutrales. Nada se borró.\n\n'
    printf 'Para revertir: mueve estas carpetas a su lugar original.\n'
    printf 'Si todo funciona bien, puedes borrar esta carpeta entera.\n'
}

plantilla_respaldo_txt_en() {
    # $1 = backup date
    printf 'Backup made by Trawün on %s\n\n' "$1"
    printf 'This is what the project carried for Claude Code and that Trawün\n'
    printf 'moved away to leave the neutral paths in place. Nothing was deleted.\n\n'
    printf 'To revert: move these folders back to where they were.\n'
    printf 'If everything works, you can delete this whole folder.\n'
}

plantilla_boost_config_es() {
    cat <<'PHP'
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
}

plantilla_boost_config_en() {
    cat <<'PHP'
<?php

/*
|--------------------------------------------------------------------------
| Laravel Boost configuration
|--------------------------------------------------------------------------
|
| Boost writes the assistant guidelines and the development skills. By default
| it leaves them in Claude Code's own paths (`CLAUDE.md` and `.claude/skills`);
| this project uses the neutral paths that most assistants understand (DSH,
| Qoder, Codex, Cursor, Amp, Zed, OpenCode): `AGENTS.md` and `.agents/skills`.
|
| Boost ships no "neutral" agent, so `claude_code` is kept in boost.json and
| its paths are redirected here. Configuring it (instead of renaming the files
| by hand) is what keeps `composer update` — which triggers `boost:update` —
| from recreating the old files and leaving duplicated guidelines behind.
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
}

plantilla_boost_json_es() {
    cat <<'PHP'
$ruta = "boost.json";
$datos = json_decode((string) file_get_contents($ruta), true);
if (! is_array($datos)) { fwrite(STDERR, "boost.json no es JSON válido\n"); exit(1); }
$datos["mcp"] = false;
file_put_contents($ruta, json_encode($datos, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
PHP
}

plantilla_boost_json_en() {
    cat <<'PHP'
$ruta = "boost.json";
$datos = json_decode((string) file_get_contents($ruta), true);
if (! is_array($datos)) { fwrite(STDERR, "boost.json is not valid JSON\n"); exit(1); }
$datos["mcp"] = false;
file_put_contents($ruta, json_encode($datos, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
PHP
}

# ---------------------------------------------------------------------------
ayuda() {
    banner
    decir ayuda
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--dry-run)   DRY_RUN="si" ;;
            -y|--si|--yes)  RESPUESTA_SI="si" ;;
            -l|--idioma|--language)
                            # Sin valor no se toca el idioma: se avisa después,
                            # ya en el idioma que se haya podido deducir.
                            if [ $# -gt 1 ]; then
                                IDIOMA_PEDIDO="$2"; IDIOMA_DADO="si"; shift
                            else
                                OPCION_SIN_VALOR="$1"
                            fi ;;
            --asistentes|--assistants)
                            if [ $# -gt 1 ]; then
                                ASISTENTES_PEDIDOS="$2"; shift
                            else
                                OPCION_SIN_VALOR="$1"
                            fi ;;
            --sin-enlaces|--no-links)
                            SIN_ENLACES="si" ;;
            -h|--ayuda|--help)
                            PEDIR_AYUDA="si"; PREGUNTAR_IDIOMA="no" ;;
            -v|--version)   PEDIR_VERSION="si"; PREGUNTAR_IDIOMA="no" ;;
            y|crear)        MODO="crear"; shift; break ;;
            -*)             OPCION_MALA="$1"; break ;;
            *)              RUTA="$1" ;;
        esac
        shift
    done

    # El idioma se decide antes de imprimir nada: hasta el banner está traducido.
    elegir_idioma

    if [ -n "$OPCION_MALA" ]; then
        printf '%s%s%s\n' "$ERROR" "$(decir error_opcion "$OPCION_MALA")" "$FIN" >&2
        exit 2
    fi

    if [ -n "$OPCION_SIN_VALOR" ]; then
        printf '%s%s%s\n' "$ERROR" "$(decir error_falta_valor "$OPCION_SIN_VALOR")" "$FIN" >&2
        exit 2
    fi

    if [ "$PEDIR_AYUDA" = "si" ]; then
        ayuda
        exit 0
    fi

    if [ "$PEDIR_VERSION" = "si" ]; then
        printf 'trawun %s\n' "$VERSION"
        exit 0
    fi

    if [ "$MODO" = "crear" ] && [ $# -eq 0 ]; then
        printf '%s%s%s\n' "$ERROR" "$(decir error_falta_comando)" "$FIN" >&2
        printf '%s\n' "$(decir error_falta_comando_2)" >&2
        exit 2
    fi

    if [ "$MODO" = "adaptar" ] && [ -n "$RUTA" ]; then
        if [ ! -d "$RUTA" ]; then
            printf '%s%s%s\n' "$ERROR" "$(decir error_carpeta "$RUTA")" "$FIN" >&2
            exit 2
        fi
        cd "$RUTA"
    fi

    if [ "$MODO" = "crear" ]; then
        crear_proyecto "$@"
    fi

    PROYECTO="$(pwd)"
    detectar
    elegir_asistentes
    prever_pasos
    mostrar_plan

    # La simulación no cambia nada, así que no pide confirmación.
    if [ "$DRY_RUN" != "si" ]; then
        confirmar_plan
    fi

    if [ "$DRY_RUN" = "si" ]; then
        printf '\n%s%s%s\n' "$AVISO" "$(decir dry_run_banda)" "$FIN"
    fi

    paso_reglas
    paso_boost
    paso_skills
    paso_sembrar
    paso_enlaces
    paso_mcp

    if [ "$DRY_RUN" = "si" ]; then
        paso verificar
        nota dry_run_verificar
        printf '\n  %s%s%s\n\n' "$OK" "$(decir resumen_dry)" "$FIN"
        exit 0
    fi

    verificar
    resumen
}

main "$@"
