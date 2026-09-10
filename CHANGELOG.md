# Cambios

## v1.2.3

- **El archivo de la convención se llama `.agents/README.md`**, no `.agents/LEEME.md`: el
  nombre en inglés es el del resto (`AGENTS.md`, `README.md`, `CHANGELOG.md`). El que explica
  el respaldo pasa de `LEEME.txt` a `README.txt` por el mismo motivo.
- **Renombra los que dejaron las versiones anteriores**: el `.agents/skills/LEEME.md` de la
  1.2.1 (que ahí dentro cuenta como skill y ensucia el descubrimiento) y el `.agents/LEEME.md`
  de la 1.2.2. Nunca pisa un archivo del usuario: si ya existe un `.agents/README.md`, el viejo
  va a `.agentes-respaldo/`. Solo toca archivos que empiezan con el encabezado que escribe
  Trawün, así que un archivo con ese nombre puesto por vos se queda como está.
- Las pruebas pasan de 89 a 100 verificaciones.

## v1.2.2

- **Un proyecto que no trae nada ya no empieza en "3/6"**: los pasos se numeran sobre los que
  de verdad corren. Antes el número venía escrito en cada título, así que en un proyecto sin
  `CLAUDE.md` ni Boost la salida arrancaba en `3/6` y parecía que dos pasos habían fallado.
- **El `LEEME` de la convención se muda a `.agents/LEEME.md`**: dentro de `.agents/skills/`
  cualquier `.md` suelto cuenta como skill de un solo archivo, y los asistentes avisaban
  ("missing YAML frontmatter") en cada sesión de cada proyecto nuevo.
- **Los archivos sembrados ya no prometen enlaces que no existen**: el `AGENTS.md` y el `LEEME`
  decían siempre que `.qoder/skills/` tenía enlaces, incluso con `--sin-enlaces`, sin Qoder o
  sin un solo skill. Ahora la frase se arma con los enlaces que de verdad se crean.
- **Sin skills no se crea la carpeta del asistente**: `.qoder/skills/` vacío no servía de nada y
  además hacía que la próxima corrida creyera que el proyecto ya usa Qoder (se detecta por su
  carpeta). El plan y el resumen tampoco anuncian enlaces en ese caso, y la verificación ya no
  dice "todos los enlaces resuelven" cuando no hay ninguno.
- **Fuera de un repositorio git ya no se sugiere `git status && git diff`**: en un proyecto
  nuevo sin git el cierre daba un error. Ahora explica cómo iniciarlo.
- Limpieza: una asignación duplicada de `PROYECTO` que había quedado pegada dos veces.

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
