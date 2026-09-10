# Cambios

## v1.2.1

- El plan ya no anuncia una mudanza que no va a ocurrir: si los skills de un asistente ya
  están unificados en `.agents/skills/`, lo dice en vez de prometer moverlos. Pasa cada vez
  que corres Trawün por segunda vez sobre el mismo proyecto.
- Prueba nueva con la forma exacta que deja Trawün (enlaces en `.qoder/skills` apuntando a
  `.agents/skills`), para garantizar que volver a correrlo no duplica ni rompe nada.

## v1.2.0

- **Unifica los skills de cualquier asistente**: si el proyecto ya los tiene en `.cursor/skills/`,
  `.github/skills/` o `.qoder/skills/`, los mueve a `.agents/skills/` y deja el enlace de vuelta
  cuando el asistente lo necesita. Antes solo miraba `.claude/skills/`, así que esos skills
  quedaban invisibles para DSH y compañía.
- **Corregido un falso positivo**: Copilot se detectaba por la existencia de `.github/`, y casi
  cualquier repositorio tiene `.github/workflows/`. Ahora se exige `.github/skills/`. Antes,
  Trawün ofrecía crear enlaces de Copilot en proyectos que no lo usan.
- **No mueve skills que dejarían ciego a un asistente**: si Qoder o Copilot tienen sus skills en
  su carpeta y no pediste enlaces para ellos, se quedan donde están y te avisa. Moverlos sin
  enlace de vuelta los haría desaparecer de ese asistente.
- Reconoce Cursor y lo informa: lee `.agents/skills/` directamente, así que no necesita enlaces.
- Las pruebas pasan de 50 a 58 verificaciones.

## v1.1.0

- **Modo crear**: `trawun y <comando>` corre tu comando de creación, detecta la carpeta que
  apareció (por diferencia antes/después, no adivinando el nombre), entra y adapta el proyecto.
  Ofrece `git init` si el generador no lo hizo, y nunca adapta la carpeta actual por error.
- **Los enlaces de asistente son opcionales**: `--asistentes qoder,copilot` o `--sin-enlaces`.
  Sin flags, Trawün detecta qué hay instalado y pregunta. Si no detecta nada, no crea nada.
- **Cursor salió de la lista**: su documentación dice que lee `.agents/skills/` directamente, así
  que crearle `.cursor/skills/` sería trabajo inútil. Quedan Qoder y Copilot, que sí usan carpeta
  propia.
- Las pruebas pasaron de 22 a 50 verificaciones, e incluyen los escenarios de creación y de
  asistentes. Antes dependían de que Qoder estuviera instalado en la máquina; ahora son
  deterministas.

## v1.0.1

- **`instalar.sh`** — nuevo: deja el comando `trawun` disponible en el PATH. Elige
  `~/.local/bin`, baja el script, da permisos, y pregunta antes de tocar el archivo de
  perfil. Acepta `--dir`, `--version`, `--perfil` y `--sin-perfil`.
- **README** — sección de instalación, las garantías al principio, y la advertencia de
  que en macOS ni `~/bin` ni `~/.local/bin` están en el PATH por defecto.
- **CHANGELOG** — este archivo.

## v1.0.0 — 2026-09-10

Primera versión pública.

### Incluye

- **`trawun.sh`** — adapta cualquier proyecto a las rutas neutrales: mueve las reglas de
  `CLAUDE.md` a `AGENTS.md`, los skills de `.claude/skills/` a `.agents/skills/`, crea los
  enlaces de `.qoder/skills/`, redirige Laravel Boost si está presente, y verifica el
  resultado. Con `--dry-run`, `--si`, `--ayuda` y `--version`.
- **`instalar.sh`** — deja el comando `trawun` disponible en el PATH, y pregunta antes de
  modificar el archivo de perfil.
- **`pruebas.sh`** — 22 verificaciones sobre carpetas temporales.

### Decisiones que vale la pena conocer

- **No escribe fuera del proyecto**, nunca: la adaptación no toca la carpeta de usuario.
  Por eso el instalador es un archivo aparte, y hay que correrlo a propósito.
- **No instala skills de forma global.** Un skill global aparece en todos los proyectos,
  incluso donde no tiene nada que hacer.
- **No borra nada**: lo que sobra queda respaldado en `.agentes-respaldo/`.
- **Compatible con bash 3.2**, el que trae macOS (sin arrays asociativos, sin `mapfile`).
- **Funciona en los tres escenarios** sin que el usuario elija: proyecto con archivos de
  Claude Code, proyecto vacío (siembra) y proyecto ya adaptado (verifica).
- Si el sistema no permite enlaces simbólicos, copia los skills y lo advierte.
