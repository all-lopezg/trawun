# Trawün

> Convenciones de agentes para tu proyecto, sin depender de Claude Code.

**Trawün** (del mapuzungun: la junta, la reunión donde se conversa y se acuerda) deja
cualquier proyecto listo para los asistentes que leen el estándar neutral — `AGENTS.md`
y `.agents/skills/` — y crea los enlaces que **Qoder** necesita en `.qoder/skills/`.

Habla español e inglés: la primera vez te pregunta en cuál, y después se elige con
`--idioma en` o con `export TRAWUN_IDIOMA=en`.

## Úsalo

```bash
cd tu-proyecto
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh | bash
```

¿El proyecto todavía no existe? Trawün lo crea y lo adapta de una vez:

```bash
trawun y cargo new gestor
trawun y composer create-project artisan-build/laravel-nodeless mi-app
```

Corre tu comando de creación tal cual —con su salida y sus preguntas a la vista—, detecta
la carpeta que apareció, entra y aplica lo mismo de abajo.

Eso es todo. Antes de tocar nada, Trawün:

- **Te muestra el plan y te pide confirmación.** Nada pasa sin que lo autorices.
- **No escribe fuera del proyecto.** Nunca toca tu carpeta de usuario.
- **No borra: respalda.** Lo que sobra va a `.agentes-respaldo/`, con un `README.txt`.
- **No hace commit.** Al final te muestra el diff y decides tú.
- **No inventa reglas.** Si ya tienes `AGENTS.md`, lo respeta.

¿Prefieres verlo antes? Siempre puedes:

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh -o trawun.sh
less trawun.sh
bash trawun.sh
```

Y para ver el plan sin ejecutarlo:

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh | bash -s -- -n
```

## El problema

Casi todos los starter kits y plantillas traen sus archivos para **Claude Code**:
`CLAUDE.md`, `.claude/skills/`, `.mcp.json`. Si trabajas con Qoder, DSH, Codex, Cursor,
Zed, Amp u OpenCode, esos archivos no se leen: tu proyecto queda sin reglas y sin skills,
y lo peor es que **falla en silencio**. No hay error. Simplemente el asistente no sabe
nada de tu proyecto.

Renombrarlos a mano tampoco sirve cuando hay un generador detrás: Laravel Boost, por
ejemplo, los vuelve a crear en la siguiente actualización, y terminas con las guías
duplicadas.

Trawün hace ese trabajo por ti, y sirve igual si tu proyecto no trae nada: en ese caso
**siembra** la estructura y te deja un `AGENTS.md` con secciones para completar.

## Instalar como comando

Si vas a usarlo seguido, deja `trawun` disponible en tu terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/instalar.sh | bash
```

El instalador elige `~/.local/bin`, baja el script, le da permisos, y **te pregunta
antes de tocar tu archivo de perfil** (`.zshrc`, `.bashrc`) si esa carpeta no está en tu
PATH. Si prefieres que no lo toque: `--sin-perfil`.

Opciones: `--dir <ruta>`, `--version <tag>`, `--perfil <ruta>`, `--sin-perfil`.

Después, en una terminal nueva:

```bash
cd tu-proyecto
trawun
```

> **En macOS, `~/bin` y `~/.local/bin` no están en el PATH** por defecto. En Linux,
> `~/.local/bin` normalmente sí. Por eso el instalador te avisa y te ofrece la línea
> exacta que hace falta.

**¿Y si eres un equipo?** Descarguen `trawun.sh` al repositorio y commitéenlo. Así
cualquiera lo corre sin depender de internet y queda versionado junto al proyecto.

## Idioma

Trawün habla español e inglés, y el idioma se elige así, en este orden:

1. `--idioma es|en` (o `--language`) para esa corrida.
2. `TRAWUN_IDIOMA`, que puedes exportar en tu perfil y olvidarte.
3. Si no hay ninguna de las dos y hay terminal, **te pregunta**, con el idioma de tu
   sistema como opción por defecto.
4. Sin terminal (CI, scripts), el idioma del sistema.

```bash
trawun --idioma en              # esta corrida, en inglés
export TRAWUN_IDIOMA=es         # esta terminal (y las que abra) en español
bash instalar.sh --language en  # el instalador, en inglés
```

Vale para todo lo que Trawün imprime y también para lo que escribe dentro del proyecto:
el `AGENTS.md` inicial, el `.agents/README.md`, el `README.txt` del respaldo y la
configuración de Boost salen en el idioma elegido, no en el del script.

## Para qué asistentes

Casi todos leen el estándar neutral directamente, así que **no necesitan nada**:

| Asistente | De dónde lee los skills |
|---|---|
| DSH | `.agents/skills/` |
| Codex | `.agents/skills/` |
| Cursor | `.agents/skills/` (está en su [documentación](https://cursor.com/help/customization/skills.md)) |
| Zed, Amp, OpenCode, Antigravity | `.agents/skills/` |

Unos pocos usan una carpeta propia, y esos sí reciben enlaces:

| Asistente | Su carpeta | Cómo pedirlo |
|---|---|---|
| **Qoder** | `.qoder/skills/` | `--asistentes qoder` |
| **Copilot** | `.github/skills/` | `--asistentes copilot` |

Si no pasas `--asistentes`, Trawün mira qué tienes instalado y **te pregunta**; si no detecta
ninguno, no crea enlaces y sigue. Así tu repo no se llena de carpetas de asistentes que no usas.

```bash
trawun --asistentes qoder,copilot    # los dos
trawun --sin-enlaces                 # ninguno, solo AGENTS.md y .agents/skills
```

### De dónde los recoge

Trawün no solo crea la estructura: si el proyecto **ya tiene skills** en la carpeta de algún
asistente, los unifica en `.agents/skills/` y deja el enlace de vuelta cuando hace falta.

| Si el proyecto ya tiene… | Qué hace |
|---|---|
| `.claude/skills/` | Mueve los skills y respalda `.claude/` |
| `.cursor/skills/` | Mueve los skills; no hace falta enlace (Cursor lee la ruta neutral) |
| `.github/skills/` | Mueve los skills y enlaza de vuelta, si pediste `copilot` |
| `.qoder/skills/` | Mueve los skills y enlaza de vuelta, si pediste `qoder` |

Dos detalles que evitan desastres silenciosos:

- Si un asistente **no lee la ruta neutral** y no le vas a dejar enlaces, Trawün **no toca sus
  skills**: moverlos lo dejaría sin verlos. Te avisa y te dice el comando para unificarlos.
- Copilot se detecta por `.github/skills/`, **no** por `.github/`. Casi cualquier repo tiene
  `.github/workflows/` sin usar Copilot, y preguntar por eso sería ruido en todos lados.

## Qué hace

1. **Mira qué trae el proyecto**: `CLAUDE.md`, `.claude/`, `.mcp.json`, `AGENTS.md`,
   `.agents/`, `.qoder/`, y si usa Laravel Boost.
2. **Te muestra el plan y pide confirmación** antes de tocar nada.
3. **Respalda lo que va a mover** en `.agentes-respaldo/<fecha>/`, con un `README.txt`
   que explica cómo revertirlo.
4. **Mueve las reglas** de `CLAUDE.md` a `AGENTS.md`, conservando el contenido y la
   historia de git.
5. **Mueve los skills** de `.claude/skills/` a `.agents/skills/`.
6. **Redirige Laravel Boost** si está presente, para que escriba en las rutas neutrales
   y no vuelva a crear los archivos antiguos.
7. **Crea los enlaces** de `.qoder/skills/` hacia `.agents/skills/`, sin duplicar archivos. Si
   el proyecto todavía no tiene skills no deja carpetas vacías: los crea la próxima corrida.
8. **Verifica** el resultado y sale con error si algo quedó a medias.

Es idempotente: correrlo dos veces no rompe ni duplica nada. Y funciona igual en los tres
escenarios posibles, sin que tengas que saber en cuál estás: proyecto con archivos de
Claude Code, proyecto vacío, o proyecto ya adaptado.

## Cómo queda un proyecto

```
tu-proyecto/
├── AGENTS.md            ← las reglas, que leen DSH, Qoder, Codex, Cursor, Zed…
├── .agents/README.md    ← la convención de skills, por si se te olvida
├── .agents/skills/      ← los skills reales, una sola copia
│   └── mi-skill/SKILL.md
├── .qoder/skills/       ← enlaces, solo si pediste Qoder (o .github/skills para Copilot)
│   └── mi-skill -> ../../.agents/skills/mi-skill
└── .agentes-respaldo/   ← lo que traía para Claude Code (puedes borrarlo)
```

## Opciones

| Opción | Qué hace |
|---|---|
| `-n`, `--dry-run` | Muestra qué haría, sin tocar un solo archivo |
| `-y`, `--si` | Responde sí a todo (para automatizar) |
| `-l`, `--idioma <es\|en>` | En qué idioma habla (también `TRAWUN_IDIOMA`) |
| `--asistentes <lista>` | Para qué asistentes crear enlaces: `qoder`, `copilot` |
| `--sin-enlaces` | No crear enlaces de ningún asistente |
| `-h`, `--ayuda` | Muestra la ayuda |
| `-v`, `--version` | Muestra la versión |

Las opciones también tienen su nombre en inglés: `--language`, `--yes`, `--assistants`,
`--no-links` y `--help`.

```bash
trawun -n                       # simular sobre el proyecto actual
trawun ~/mi-proyecto            # adaptar otra carpeta
trawun -y                       # sin preguntas
trawun --idioma en              # en inglés
trawun --asistentes qoder       # enlaces solo para Qoder
trawun y cargo new gestor       # crear el proyecto y adaptarlo
```

Con `curl | bash` la entrada estándar es el propio script, así que para pasarle opciones
hay que usar `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh | bash -s -- -n
```

## Requisitos

- **bash 3.2 o superior** — funciona con el bash viejo que trae macOS.
- **git** es opcional: si el proyecto es un repo, Trawün usa `git mv` para conservar la
  historia de los archivos; si no, mueve igual.
- **PHP** solo hace falta si el proyecto usa Laravel Boost (para correr `boost:update`).
- **curl** o **wget**, solo si lo corres desde la red en vez de tenerlo en disco.

## Preguntas frecuentes

**¿Sirve para Rust, React, HTMX, Go…?**
Sí. El contrato es el mismo para todos: markdown y enlaces, nada específico de un
lenguaje. Si el proyecto no trae nada de agentes, Trawün siembra la estructura.

**¿Trawün crea enlaces para todos los asistentes?**
No, y es a propósito. Solo hacen falta para los que usan carpeta propia (Qoder, Copilot); el
resto lee `.agents/skills/` directamente. Crear carpetas que nadie va a leer es justamente la
clase de ruido que Trawün intenta evitar.

**¿Y si mi proyecto trae `.mcp.json`?**
Trawün te pregunta: **Qoder sí lee ese archivo** (alcance de proyecto), pero cada
servidor MCP suma sus herramientas a cada mensaje que envíes. Decide según lo que
necesites, no por reflejo. DSH, en cambio, no soporta MCP por proyecto: su configuración
es del perfil, no del repo.

**¿En Windows funciona?**
Sí, con un matiz: si el sistema no permite enlaces simbólicos, Trawün **copia** los
skills en `.qoder/skills/` en vez de enlazarlos. Funciona igual, ocupa más, y hay que
volver a correrlo si cambias un skill.

**¿Por qué no instalar los skills a nivel de usuario y listo?**
Porque entonces aparecen en **todos** tus proyectos, incluso donde no tienen nada que
hacer. Un skill de un BaaS que se activa con "agregar autenticación" o "subir archivos"
no tiene por qué ofrecerse en un proyecto que no lo usa. Los skills viven en el proyecto.

**¿Y mis comandos y agentes de `.claude/`?**
Van al respaldo junto con el resto, y Trawün te los nombra al hacerlo. No los convierte
automáticamente a otro formato: Qoder tiene su propio mecanismo de comandos y de agentes,
y esa decisión es tuya.

**¿Trawün lee algo de mi proyecto?**
Solo mira qué archivos existen para armar el plan, y lee `CLAUDE.md` para moverlo tal cual
—no interpreta su contenido—. No manda nada a ningún servidor.

## English

**Trawün** prepares any project for AI assistants that read the neutral standard
(`AGENTS.md` + `.agents/skills/`) instead of Claude Code's files, and creates the
symlinks Qoder looks for in `.qoder/skills/`.

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/all-lopezg/trawun/main/trawun.sh | bash
```

It speaks Spanish and English: it asks you once, and after that you can pin it with
`--language en` or `export TRAWUN_IDIOMA=en`. Everything it prints and everything it
writes into the project (the starter `AGENTS.md`, the `.agents/README.md`, the backup
README and the Boost config) comes out in the language you chose.

It can also create the project for you: `trawun y cargo new gestor` runs your command, finds
the new folder, and adapts it. Install it as a command with `instalar.sh`, or run `--dry-run`
to see the plan first. Only assistants with their own skills folder need symlinks (Qoder,
Copilot); the rest read `.agents/skills/` directly.
It never writes outside the project, never installs skills globally, never deletes
anything (it moves it to `.agentes-respaldo/`), and never commits. Works with bash 3.2+
(including macOS's ancient bash).

## Cambios y licencia

Ver [CHANGELOG.md](CHANGELOG.md). Licencia MIT: ver [LICENSE](LICENSE).
