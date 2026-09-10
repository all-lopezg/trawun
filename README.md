# Trawün

> Convenciones de agentes para tu proyecto, sin depender de Claude Code.

**Trawün** (del mapuzungun: la junta, la reunión donde se conversa y se acuerda) deja
cualquier proyecto listo para los asistentes que leen el estándar neutral — `AGENTS.md`
y `.agents/skills/` — y crea los enlaces que **Qoder** necesita en `.qoder/skills/`.

## El problema

Casi todos los starter kits y plantillas traen sus archivos para **Claude Code**:
`CLAUDE.md`, `.claude/skills/`, `.mcp.json`. Si trabajas con Qoder, DSH, Codex, Cursor,
Zed, Amp u OpenCode, esos archivos no se leen: tu proyecto queda sin reglas y sin skills,
y lo peor es que **falla en silencio**. No hay error. Simplemente el asistente no sabe
nada de tu proyecto.

Renombrarlos a mano tampoco sirve cuando hay un generador detrás: Laravel Boost, por
ejemplo, los vuelve a crear en la siguiente actualización, y terminas con las guías
duplicadas.

## Inicio rápido

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh | bash
```

O, si prefieres leerlo antes de ejecutarlo (recomendado la primera vez):

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh -o trawun.sh
less trawun.sh
bash trawun.sh
```

Corre dentro de la carpeta del proyecto. No necesita instalación.

## Qué hace

1. **Mira qué trae el proyecto**: `CLAUDE.md`, `.claude/`, `.mcp.json`, `AGENTS.md`,
   `.agents/`, `.qoder/`, y si usa Laravel Boost.
2. **Te muestra el plan y pide confirmación** antes de tocar nada.
3. **Respalda lo que va a mover** en `.agentes-respaldo/<fecha>/`, con un `LEEME.txt`
   que explica cómo revertirlo. Nada se borra.
4. **Mueve las reglas** de `CLAUDE.md` a `AGENTS.md`, conservando el contenido.
5. **Mueve los skills** de `.claude/skills/` a `.agents/skills/`.
6. **Redirige Laravel Boost** si está presente, para que escriba en las rutas neutrales
   y no vuelva a crear los archivos antiguos.
7. **Crea los enlaces** de `.qoder/skills/` hacia `.agents/skills/`, sin duplicar archivos.
8. **Verifica** el resultado y sale con error si algo quedó a medias.

## Qué NO hace

- **No escribe fuera del proyecto.** Nunca toca tu carpeta de usuario.
- **No instala nada de forma global.** Los skills son del proyecto y de ningún otro.
- **No borra nada**: lo que sobra se mueve al respaldo.
- **No hace commit**: al final te muestra el diff y decides tú.
- **No inventa reglas**: si ya tienes `AGENTS.md`, lo respeta.

## Cómo queda un proyecto

```
tu-proyecto/
├── AGENTS.md            ← las reglas, que leen DSH, Qoder, Codex, Cursor, Zed…
├── .agents/skills/      ← los skills reales, una sola copia
│   └── mi-skill/SKILL.md
├── .qoder/skills/       ← enlaces a los anteriores, para Qoder
│   └── mi-skill -> ../../.agents/skills/mi-skill
└── .agentes-respaldo/   ← lo que traía para Claude Code (puedes borrarlo)
```

## Opciones

| Opción | Qué hace |
|---|---|
| `-n`, `--dry-run` | Muestra qué haría, sin tocar un solo archivo |
| `-y`, `--si` | Responde sí a todo (para automatizar) |
| `-h`, `--ayuda` | Muestra la ayuda |
| `-v`, `--version` | Muestra la versión |

```bash
bash trawun.sh -n              # simular sobre el proyecto actual
bash trawun.sh ~/mi-proyecto   # adaptar otra carpeta
bash trawun.sh -y              # sin preguntas
```

## Requisitos

- **bash 3.2 o superior** — funciona con el bash viejo que trae macOS.
- **git** es opcional: si el proyecto es un repo, Trawün usa `git mv` para conservar
  la historia de los archivos; si no, mueve igual.
- **PHP** solo hace falta si el proyecto usa Laravel Boost (para correr `boost:update`).

## Preguntas frecuentes

**¿Sirve para Rust, React, HTMX, Go…?**
Sí. El contrato es el mismo para todos: markdown y enlaces, nada específico de un
lenguaje. Si el proyecto no trae nada de agentes, Trawün **siembra** la estructura y te
deja un `AGENTS.md` con secciones para completar.

**¿Y si mi proyecto trae `.mcp.json`?**
Trawün te pregunta: **Qoder sí lee ese archivo** (alcance de proyecto), pero cada
servidor MCP suma sus herramientas a cada mensaje que envíes. Decide según lo que
necesites, no por reflejo. DSH, en cambio, no soporta MCP por proyecto: su
configuración es del perfil, no del repo.

**¿En Windows funciona?**
Sí, con un matiz: si el sistema no permite enlaces simbólicos, Trawün **copia** los
skills en `.qoder/skills/` en vez de enlazarlos. Funciona igual, ocupa más, y hay que
volver a correrlo si cambias un skill.

**¿Por qué no instalar los skills a nivel de usuario y listo?**
Porque entonces aparecen en **todos** tus proyectos, incluso donde no tienen nada que
hacer. Un skill de un BaaS que activa con "agregar autenticación" o "subir archivos" no
tiene por qué ofrecerse en un proyecto que no lo usa. Los skills viven en el proyecto.

**¿Y mis comandos y agentes de `.claude/`?**
Van al respaldo junto con el resto, y Trawün te los nombra al hacerlo. No los convierte
automáticamente a otro formato: Qoder tiene su propio mecanismo de comandos y de
agentes, y esa decisión es tuya.

## English

**Trawün** prepares any project for AI assistants that read the neutral standard
(`AGENTS.md` + `.agents/skills/`) instead of Claude Code's files, and creates the
symlinks Qoder looks for in `.qoder/skills/`.

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh | bash
```

It never writes outside the project, never installs skills globally, never deletes
anything (it moves it to `.agentes-respaldo/`), and never commits. Use `--dry-run` to
see the plan first. Works with bash 3.2+ (including macOS's ancient bash).

## Licencia

MIT. Ver [LICENSE](LICENSE).
