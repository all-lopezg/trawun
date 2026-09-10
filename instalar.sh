#!/usr/bin/env bash
#
# Trawün — instalador
#
# Deja el comando `trawun` disponible en tu terminal.
#
# Uso:  bash instalar.sh [opciones]
#
# Esto es un archivo aparte a propósito: `trawun.sh` promete no escribir nunca
# fuera del proyecto que adapta, y esa promesa se mantiene. Este instalador sí
# escribe en tu carpeta de usuario, porque es exactamente su trabajo — y siempre
# te pregunta antes.
#
# Habla español e inglés, igual que trawun.sh: el idioma sale del sistema donde
# se corre, --idioma y TRAWUN_IDIOMA lo cambian, y solo si el sistema no dice
# nada se pregunta.
#
set -eu

VERSION="1.3.1"
REPO="all-lopezg/trawun"
RAMIFICACION="main"

DESTINO="${TRAWUN_DESTINO:-}"
PERFIL=""
AGREGAR_AL_PERFIL="preguntar"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    TITULO=$'\033[1;36m'; OK=$'\033[32m'; AVISO=$'\033[33m'
    ERROR=$'\033[31m'; GRIS=$'\033[90m'; FIN=$'\033[0m'
else
    TITULO=""; OK=""; AVISO=""; ERROR=""; GRIS=""; FIN=""
fi

# ---------------------------------------------------------------------------
# Idioma
#
# Mismo mecanismo que en trawun.sh: cada idioma es un catálogo con las mismas
# claves (mensaje_es y mensaje_en, al final), y `decir <clave> [datos]` llama al
# del idioma activo.
# ---------------------------------------------------------------------------
IDIOMA="es"
IDIOMA_PEDIDO=""
IDIOMA_DADO="no"
PREGUNTAR_IDIOMA="si"

decir() {
    "mensaje_$IDIOMA" "$@"
}

normalizar_idioma() {
    case "$1" in
        [Ee][Ss]|[Ee][Ss][-_]*|[Ee]spanol|[Ee]spañol|[Cc]astellano|1) printf 'es' ;;
        [Ee][Nn]|[Ee][Nn][-_]*|[Ee]nglish|[Ii]ngles|[Ii]nglés|2)       printf 'en' ;;
        *)                                                            printf '' ;;
    esac
}

idioma_del_sistema() {
    # El idioma de la máquina donde corre el script. Devuelve vacío cuando no
    # dice nada (LANG=C, contenedores sin locale), que no es lo mismo que decir
    # español: quien decide eso es elegir_idioma.
    for valor in "${LC_ALL:-}" "${LC_MESSAGES:-}" "${LANG:-}"; do
        encontrado="$(normalizar_idioma "$valor")"
        [ -n "$encontrado" ] && { printf '%s' "$encontrado"; return 0; }
    done

    # En macOS LANG suele estar vacío y el idioma vive en las preferencias.
    if [ "$(uname -s)" = "Darwin" ] && command -v defaults >/dev/null 2>&1; then
        encontrado="$(normalizar_idioma "$(defaults read -g AppleLocale 2>/dev/null || true)")"
        [ -n "$encontrado" ] && { printf '%s' "$encontrado"; return 0; }
    fi

    printf ''
}

preguntar_idioma() {
    # La pregunta va en los dos idiomas: todavía no hay uno elegido.
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
    # El idioma sale del sistema donde se corre el script, sin preguntar nada.
    # Lo elegido a mano (bandera o variable) manda sobre eso, siempre. La
    # pregunta queda como último recurso: solo cuando el sistema no dice nada,
    # porque adivinar ahí sería peor que preguntar una vez.
    del_sistema="$(idioma_del_sistema)"

    pedido="$IDIOMA_PEDIDO"
    if [ -z "$pedido" ]; then
        pedido="${TRAWUN_IDIOMA:-}"
    fi
    if [ -z "$pedido" ]; then
        pedido="${TRAWUN_LANG:-}"
    fi

    IDIOMA="$del_sistema"
    [ -z "$IDIOMA" ] && IDIOMA="es"

    if [ -n "$pedido" ] || [ "$IDIOMA_DADO" = "si" ]; then
        elegido="$(normalizar_idioma "$pedido")"
        if [ -z "$elegido" ]; then
            printf '%s%s%s\n' "$ERROR" "$(decir idioma_desconocido "$pedido")" "$FIN" >&2
            printf '%s\n' "$(decir idioma_conocidos)" >&2
            exit 2
        fi
        IDIOMA="$elegido"
        return 0
    fi

    if [ -z "$del_sistema" ] && [ "$PREGUNTAR_IDIOMA" = "si" ] && hay_terminal; then
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

ayuda() {
    banner
    decir ayuda
}

# ---------------------------------------------------------------------------
# Preguntas: con `curl | bash`, la entrada estándar es el script, así que hay
# que leer de /dev/tty.
# ---------------------------------------------------------------------------
hay_terminal() {
    { exec 3</dev/tty; } 2>/dev/null || return 1
    exec 3<&-
    return 0
}

preguntar() {
    # $1 = clave de la pregunta, $2 = respuesta por defecto (si/no), resto = datos
    if ! hay_terminal; then
        aviso pregunta_sin_terminal
        nota pregunta_sin_terminal_2
        return 1
    fi

    printf '     %s%s' "$(decir "$1" "${@:3}")" "$(decir pregunta_sufijo)"
    exec 3</dev/tty
    read -r respuesta <&3 || respuesta=""
    exec 3<&-
    [ -z "$respuesta" ] && respuesta="$2"

    case "$respuesta" in
        s|S|si|SI|Si|y|Y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
main() {
    OPCION_MALA=""
    OPCION_SIN_VALOR=""
    PEDIR_AYUDA="no"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dir)          if [ $# -gt 1 ]; then DESTINO="$2"; shift
                            else OPCION_SIN_VALOR="$1"; fi ;;
            --version)      if [ $# -gt 1 ]; then RAMIFICACION="$2"; shift
                            else OPCION_SIN_VALOR="$1"; fi ;;
            --perfil)       if [ $# -gt 1 ]; then PERFIL="$2"; shift
                            else OPCION_SIN_VALOR="$1"; fi ;;
            -l|--idioma|--language)
                            if [ $# -gt 1 ]; then
                                IDIOMA_PEDIDO="$2"; IDIOMA_DADO="si"; shift
                            else
                                OPCION_SIN_VALOR="$1"
                            fi ;;
            --sin-perfil|--no-profile)
                            AGREGAR_AL_PERFIL="no" ;;
            -h|--ayuda|--help)
                            PEDIR_AYUDA="si"; PREGUNTAR_IDIOMA="no" ;;
            -*)             OPCION_MALA="$1"; break ;;
            *)              OPCION_MALA="$1"; break ;;
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

    # Destino por defecto: ~/.local/bin, que en Linux suele estar en el PATH y es
    # la convención XDG para binarios del usuario.
    if [ -z "$DESTINO" ]; then
        DESTINO="$HOME/.local/bin"
    fi

    AQUI="$(cd "$(dirname "$0")" && pwd)"
    DESTINO_ARCHIVO="$DESTINO/trawun"
    URL="https://raw.githubusercontent.com/$REPO/$RAMIFICACION/trawun.sh"

    banner

    decir instalar_en "$DESTINO_ARCHIVO"

    # --- 1. Carpeta ---------------------------------------------------------
    if [ ! -d "$DESTINO" ]; then
        if mkdir -p "$DESTINO" 2>/dev/null; then
            ok carpeta_creada "$DESTINO"
        else
            falla carpeta_falla "$DESTINO"
            exit 1
        fi
    else
        ok carpeta_existe
    fi

    # --- 2. El script -------------------------------------------------------
    if [ -f "$AQUI/trawun.sh" ]; then
        cp "$AQUI/trawun.sh" "$DESTINO_ARCHIVO"
        ok copiado_local
    elif command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$URL" -o "$DESTINO_ARCHIVO"; then
            ok descargado "$RAMIFICACION"
        else
            falla descarga_falla "$URL"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -qO "$DESTINO_ARCHIVO" "$URL"; then
            ok descargado "$RAMIFICACION"
        else
            falla descarga_falla "$URL"
            exit 1
        fi
    else
        falla sin_descargador
        exit 1
    fi

    # --- 3. Permisos --------------------------------------------------------
    if chmod +x "$DESTINO_ARCHIVO"; then
        ok permisos_ok
    else
        falla permisos_falla "$DESTINO_ARCHIVO"
        exit 1
    fi

    # --- 4. PATH ------------------------------------------------------------
    case ":$PATH:" in
        *":$DESTINO:"*)
            ok ya_en_path "$DESTINO"
            ;;
        *)
            aviso no_en_path "$DESTINO"

            if [ -z "$PERFIL" ]; then
                case "${SHELL:-}" in
                    */zsh)  PERFIL="$HOME/.zshrc" ;;
                    */bash) PERFIL="$HOME/.bashrc" ;;
                    *)      PERFIL="$HOME/.profile" ;;
                esac
            fi

            LINEA="export PATH=\"$DESTINO:\$PATH\""
            nota linea_necesaria "$LINEA"
            nota linea_va_en "$PERFIL"

            if [ "$AGREGAR_AL_PERFIL" = "no" ]; then
                aviso perfil_intocable
            elif [ -f "$PERFIL" ] && grep -qF "$LINEA" "$PERFIL" 2>/dev/null; then
                ok linea_ya_estaba "$PERFIL"
                nota terminal_nueva
            elif preguntar perfil_pregunta si "$PERFIL"; then
                {
                    printf '\n# Agregado por el instalador de Trawün\n'
                    printf '%s\n' "$LINEA"
                } >> "$PERFIL"
                ok linea_agregada "$PERFIL"
                nota terminal_nueva_o_source "$PERFIL"
            else
                aviso linea_no_agregada
                nota linea_a_mano
                nota ruta_completa "$DESTINO_ARCHIVO"
            fi
            ;;
    esac

    # --- 5. Verificación ----------------------------------------------------
    printf '\n'
    if "$DESTINO_ARCHIVO" --version >/dev/null 2>&1; then
        ok comando_responde "$("$DESTINO_ARCHIVO" --version)"
    else
        falla comando_no_responde
        exit 1
    fi

    printf '\n%s────────────────────────────────────────────────────────────%s\n' "$GRIS" "$FIN"
    printf '\n  %s%s%s\n\n' "$OK" "$(decir listo)" "$FIN"
    printf '  %s\n\n' "$(decir final_1)"
    printf '    %s%s%s\n\n' "$TITULO" "trawun" "$FIN"
    printf '  %s\n\n' "$(decir final_2)"
}

# ---------------------------------------------------------------------------
# Los mensajes: un catálogo por idioma, con las mismas claves
# ---------------------------------------------------------------------------
mensaje_es() {
    case "$1" in
        banner_linea)             printf '  %sTrawün%s · instalador · v%s\n' "$GRIS" "$FIN" "$2" ;;
        idioma_desconocido)       printf 'Idioma desconocido: %s' "$2" ;;
        idioma_conocidos)         printf 'Idiomas: es, en' ;;
        error_opcion)             printf 'Opción desconocida: %s' "$2" ;;
        error_falta_valor)        printf 'Falta el valor de %s.' "$2" ;;
        pregunta_sufijo)          printf ' [s/n] ' ;;
        pregunta_sin_terminal)    printf 'Sin terminal interactiva: no toco tu perfil.' ;;
        pregunta_sin_terminal_2)  printf 'Agrega la línea a mano (te la dejo abajo).' ;;

        instalar_en)              printf '\n  Voy a instalar el comando %strawun%s en:\n    %s\n\n' "$TITULO" "$FIN" "$2" ;;
        carpeta_creada)           printf 'carpeta creada: %s' "$2" ;;
        carpeta_falla)            printf 'no pude crear %s' "$2" ;;
        carpeta_existe)           printf 'la carpeta ya existe' ;;
        copiado_local)            printf 'copiado desde este mismo directorio (sin usar la red)' ;;
        descargado)               printf 'descargado de %s' "$2" ;;
        descarga_falla)           printf 'no pude descargar %s' "$2" ;;
        sin_descargador)          printf 'necesito curl o wget para descargarlo' ;;
        permisos_ok)              printf 'permisos de ejecución listos' ;;
        permisos_falla)           printf 'no pude darle permisos a %s' "$2" ;;
        ya_en_path)               printf '%s ya está en tu PATH' "$2" ;;
        no_en_path)               printf '%s NO está en tu PATH' "$2" ;;
        linea_necesaria)          printf 'la línea que hace falta:  %s' "$2" ;;
        linea_va_en)              printf 'iría en:  %s' "$2" ;;
        perfil_intocable)         printf 'no toco el perfil (--sin-perfil)' ;;
        linea_ya_estaba)          printf 'la línea ya estaba en %s' "$2" ;;
        terminal_nueva)           printf 'abre una terminal nueva para que tome efecto' ;;
        perfil_pregunta)          printf '¿La agrego a %s?' "$2" ;;
        linea_agregada)           printf 'agregada a %s' "$2" ;;
        terminal_nueva_o_source)  printf 'abre una terminal nueva (o corre: source %s)' "$2" ;;
        linea_no_agregada)        printf 'no la agregué' ;;
        linea_a_mano)             printf 'hazlo a mano cuando quieras, o usa la ruta completa:' ;;
        ruta_completa)            printf '  %s' "$2" ;;
        comando_responde)         printf 'el comando responde: %s' "$2" ;;
        comando_no_responde)      printf 'el archivo quedó ahí pero no responde' ;;

        listo)                    printf 'Listo.' ;;
        final_1)                  printf 'En una terminal nueva, entra a cualquier proyecto y escribe:' ;;
        final_2)                  printf 'Sin argumentos adapta el proyecto actual. Con -n te muestra el\n  plan sin tocar nada. Para actualizarlo, corre este instalador otra vez.' ;;

        ayuda)                    plantilla_ayuda_es ;;

        *)                        printf 'FALTA TEXTO (es): %s' "$1" >&2 ;;
    esac
}

mensaje_en() {
    case "$1" in
        banner_linea)             printf '  %sTrawün%s · installer · v%s\n' "$GRIS" "$FIN" "$2" ;;
        idioma_desconocido)       printf 'Unknown language: %s' "$2" ;;
        idioma_conocidos)         printf 'Languages: es, en' ;;
        error_opcion)             printf 'Unknown option: %s' "$2" ;;
        error_falta_valor)        printf 'Missing the value of %s.' "$2" ;;
        pregunta_sufijo)          printf ' [y/n] ' ;;
        pregunta_sin_terminal)    printf 'No interactive terminal: I do not touch your profile.' ;;
        pregunta_sin_terminal_2)  printf 'Add the line by hand (it is left below).' ;;

        instalar_en)              printf '\n  I am going to install the %strawun%s command in:\n    %s\n\n' "$TITULO" "$FIN" "$2" ;;
        carpeta_creada)           printf 'folder created: %s' "$2" ;;
        carpeta_falla)            printf 'I could not create %s' "$2" ;;
        carpeta_existe)           printf 'the folder is already there' ;;
        copiado_local)            printf 'copied from this very folder (no network involved)' ;;
        descargado)               printf 'downloaded from %s' "$2" ;;
        descarga_falla)           printf 'I could not download %s' "$2" ;;
        sin_descargador)          printf 'I need curl or wget to download it' ;;
        permisos_ok)              printf 'execution permissions are set' ;;
        permisos_falla)           printf 'I could not set permissions on %s' "$2" ;;
        ya_en_path)               printf '%s is already in your PATH' "$2" ;;
        no_en_path)               printf '%s is NOT in your PATH' "$2" ;;
        linea_necesaria)          printf 'the line you need:  %s' "$2" ;;
        linea_va_en)              printf 'it would go in:  %s' "$2" ;;
        perfil_intocable)         printf 'I do not touch the profile (--no-profile)' ;;
        linea_ya_estaba)          printf 'the line was already in %s' "$2" ;;
        terminal_nueva)           printf 'open a new terminal for it to take effect' ;;
        perfil_pregunta)          printf 'Add it to %s?' "$2" ;;
        linea_agregada)           printf 'added to %s' "$2" ;;
        terminal_nueva_o_source)  printf 'open a new terminal (or run: source %s)' "$2" ;;
        linea_no_agregada)        printf 'I did not add it' ;;
        linea_a_mano)             printf 'do it by hand whenever you want, or use the full path:' ;;
        ruta_completa)            printf '  %s' "$2" ;;
        comando_responde)         printf 'the command answers: %s' "$2" ;;
        comando_no_responde)      printf 'the file is there but does not answer' ;;

        listo)                    printf 'Done.' ;;
        final_1)                  printf 'In a new terminal, step into any project and type:' ;;
        final_2)                  printf 'With no arguments it adapts the current project. With -n it shows\n  the plan without touching anything. To update it, run this installer again.' ;;

        ayuda)                    plantilla_ayuda_en ;;

        *)                        printf 'MISSING TEXT (en): %s' "$1" >&2 ;;
    esac
}

plantilla_ayuda_es() {
    cat <<'AYUDA'

  Deja el comando `trawun` disponible en tu terminal, para no tener que
  escribir la línea de curl cada vez.

  Qué hace:
    1. Elige dónde instalarlo (~/.local/bin por defecto).
    2. Baja trawun.sh desde GitHub (o usa el que esté junto a este archivo).
    3. Le da permisos de ejecución.
    4. Revisa si esa carpeta está en tu PATH y, si no, te ofrece agregarla.

  Uso:
    bash instalar.sh [opciones]

  Opciones:
    --dir <ruta>          Dónde instalarlo (por defecto: ~/.local/bin)
    --version <tag>       Qué versión bajar (por defecto: main)
    --perfil <ruta>       Archivo de perfil a modificar si falta el PATH
    --sin-perfil          Nunca tocar el perfil; solo avisar
    -l, --idioma <es|en>  En qué idioma habla el instalador. También sirve la
                          variable TRAWUN_IDIOMA. Sin esto lo deduce del sistema
                          donde lo corras.
    -h, --ayuda           Muestra esta ayuda

  Las opciones también tienen su nombre en inglés: --language, --no-profile
  y --help.

  Ejemplos:
    bash instalar.sh
    bash instalar.sh --dir ~/bin
    bash instalar.sh --version v1.0.0
AYUDA
}

plantilla_ayuda_en() {
    cat <<'AYUDA'

  Leaves the `trawun` command available in your terminal, so you do not have to
  type the curl line every time.

  What it does:
    1. Picks where to install it (~/.local/bin by default).
    2. Downloads trawun.sh from GitHub (or uses the one next to this file).
    3. Gives it execution permissions.
    4. Checks whether that folder is in your PATH and, if not, offers to add it.

  Usage:
    bash instalar.sh [options]

  Options:
    --dir <path>            Where to install it (default: ~/.local/bin)
    --version <tag>         Which version to download (default: main)
    --perfil <path>         Profile file to edit if the PATH entry is missing
    --no-profile            Never touch the profile; just warn
    -l, --language <es|en>  Which language the installer speaks. The
                            TRAWUN_IDIOMA variable works too. Without it, it
                            works it out from the system it runs on.
    -h, --help              Shows this help

  The options also work with their Spanish names: --idioma, --sin-perfil
  and --ayuda.

  Examples:
    bash instalar.sh
    bash instalar.sh --dir ~/bin
    bash instalar.sh --version v1.0.0
AYUDA
}

main "$@"
