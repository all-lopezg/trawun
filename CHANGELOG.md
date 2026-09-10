# Cambios

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
