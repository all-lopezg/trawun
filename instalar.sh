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
set -eu

VERSION="1.2.0"
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

ok()    { printf '     %s✓%s %s\n' "$OK" "$FIN" "$1"; }
aviso() { printf '     %s!%s %s\n' "$AVISO" "$FIN" "$1"; }
falla() { printf '     %s✗%s %s\n' "$ERROR" "$FIN" "$1"; }
nota()  { printf '       %s%s%s\n' "$GRIS" "$1" "$FIN"; }

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
    printf '  %sTrawün%s · instalador · v%s\n' "$GRIS" "$FIN" "$VERSION"
}

ayuda() {
    banner
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
    --dir <ruta>        Dónde instalarlo (por defecto: ~/.local/bin)
    --version <tag>     Qué versión bajar (por defecto: main)
    --perfil <ruta>     Archivo de perfil a modificar si falta el PATH
    --sin-perfil        Nunca tocar el perfil; solo avisar
    -h, --ayuda         Muestra esta ayuda

  Ejemplos:
    bash instalar.sh
    bash instalar.sh --dir ~/bin
    bash instalar.sh --version v1.0.0
AYUDA
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
    # $1 = pregunta, $2 = respuesta por defecto (s/n)
    if ! hay_terminal; then
        aviso "Sin terminal interactiva: no toco tu perfil."
        nota "Agrega la línea a mano (te la dejo abajo)."
        return 1
    fi

    printf '     %s [s/n] ' "$1"
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
while [ $# -gt 0 ]; do
    case "$1" in
        --dir)        DESTINO="${2:-}"; shift ;;
        --version)    RAMIFICACION="${2:-}"; shift ;;
        --perfil)     PERFIL="${2:-}"; shift ;;
        --sin-perfil) AGREGAR_AL_PERFIL="no" ;;
        -h|--ayuda)   ayuda; exit 0 ;;
        *)            printf '%sOpción desconocida: %s%s\n' "$ERROR" "$1" "$FIN" >&2; exit 2 ;;
    esac
    shift
done

# Destino por defecto: ~/.local/bin, que en Linux suele estar en el PATH y es la
# convención XDG para binarios del usuario.
if [ -z "$DESTINO" ]; then
    DESTINO="$HOME/.local/bin"
fi

AQUI="$(cd "$(dirname "$0")" && pwd)"
DESTINO_ARCHIVO="$DESTINO/trawun"
URL="https://raw.githubusercontent.com/$REPO/$RAMIFICACION/trawun.sh"

banner

printf '\n  Voy a instalar el comando %strawun%s en:\n' "$TITULO" "$FIN"
printf '    %s\n\n' "$DESTINO_ARCHIVO"

# --- 1. Carpeta -------------------------------------------------------------
if [ ! -d "$DESTINO" ]; then
    if mkdir -p "$DESTINO" 2>/dev/null; then
        ok "carpeta creada: $DESTINO"
    else
        falla "no pude crear $DESTINO"
        exit 1
    fi
else
    ok "la carpeta ya existe"
fi

# --- 2. El script -----------------------------------------------------------
if [ -f "$AQUI/trawun.sh" ]; then
    cp "$AQUI/trawun.sh" "$DESTINO_ARCHIVO"
    ok "copiado desde este mismo directorio (sin usar la red)"
elif command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$URL" -o "$DESTINO_ARCHIVO"; then
        ok "descargado de $RAMIFICACION"
    else
        falla "no pude descargar $URL"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$DESTINO_ARCHIVO" "$URL"; then
        ok "descargado de $RAMIFICACION"
    else
        falla "no pude descargar $URL"
        exit 1
    fi
else
    falla "necesito curl o wget para descargarlo"
    exit 1
fi

# --- 3. Permisos ------------------------------------------------------------
if chmod +x "$DESTINO_ARCHIVO"; then
    ok "permisos de ejecución listos"
else
    falla "no pude darle permisos a $DESTINO_ARCHIVO"
    exit 1
fi

# --- 4. PATH ----------------------------------------------------------------
case ":$PATH:" in
    *":$DESTINO:"*)
        ok "$DESTINO ya está en tu PATH"
        ;;
    *)
        aviso "$DESTINO NO está en tu PATH"

        if [ -z "$PERFIL" ]; then
            case "${SHELL:-}" in
                */zsh)  PERFIL="$HOME/.zshrc" ;;
                */bash) PERFIL="$HOME/.bashrc" ;;
                *)      PERFIL="$HOME/.profile" ;;
            esac
        fi

        LINEA="export PATH=\"$DESTINO:\$PATH\""
        nota "la línea que hace falta:  $LINEA"
        nota "iría en:  $PERFIL"

        if [ "$AGREGAR_AL_PERFIL" = "no" ]; then
            aviso "no toco el perfil (--sin-perfil)"
        elif [ -f "$PERFIL" ] && grep -qF "$LINEA" "$PERFIL" 2>/dev/null; then
            ok "la línea ya estaba en $PERFIL"
            nota "abre una terminal nueva para que tome efecto"
        elif preguntar "¿La agrego a $PERFIL?" "s"; then
            {
                printf '\n# Agregado por el instalador de Trawün\n'
                printf '%s\n' "$LINEA"
            } >> "$PERFIL"
            ok "agregada a $PERFIL"
            nota "abre una terminal nueva (o corre: source $PERFIL)"
        else
            aviso "no la agregué"
            nota "hazlo a mano cuando quieras, o usa la ruta completa:"
            nota "  $DESTINO_ARCHIVO"
        fi
        ;;
esac

# --- 5. Verificación --------------------------------------------------------
printf '\n'
if "$DESTINO_ARCHIVO" --version >/dev/null 2>&1; then
    ok "el comando responde: $("$DESTINO_ARCHIVO" --version)"
else
    falla "el archivo quedó ahí pero no responde"
    exit 1
fi

printf '\n%s────────────────────────────────────────────────────────────%s\n' "$GRIS" "$FIN"
printf '\n  %sListo.%s\n\n' "$OK" "$FIN"
printf '  En una terminal nueva, entra a cualquier proyecto y escribe:\n\n'
printf '    %s%s%s\n\n' "$TITULO" "trawun" "$FIN"
printf '  Sin argumentos adapta el proyecto actual. Con %s-n%s te muestra el\n' "$TITULO" "$FIN"
printf '  plan sin tocar nada. Para actualizarlo, corre este instalador otra vez.\n\n'
