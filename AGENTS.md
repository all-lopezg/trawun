# Trawün — reglas para quien modifica este repo

Trawün es una herramienta de terminal: un script de bash que adapta proyectos a los
asistentes de IA que leen el estándar neutral (`AGENTS.md` y `.agents/skills/`). Esto es
lo que no se deduce leyendo el código.

## Lo que es intocable

Las tres promesas del README son **decisiones de producto**, no descripciones. Si un
cambio las rompe, rompe el punto entero de la herramienta:

1. **Nunca escribe fuera del proyecto que adapta.** Por eso el instalador es un archivo
   aparte: `trawun.sh` no toca la carpeta de usuario, ni siquiera con una bandera nueva.
2. **Nunca instala skills de forma global.** Un skill global aparece en todos los
   proyectos, incluso donde no tiene nada que hacer: es el problema que Trawün resuelve.
3. **Nunca borra**: lo que sobra va a `.agentes-respaldo/`.

Si algo nuevo necesita salirse de esto, va en `instalar.sh`, no en `trawun.sh`.

## Compatibilidad

Corre en el bash 3.2 que trae macOS: nada de `declare -A`, `mapfile`, `readarray` ni
`${var,,}`. Hay una prueba que lo vigila.

Con `curl | bash` la entrada estándar **es el script**, así que todo lo que le pregunte al
usuario tiene que leer de `/dev/tty`, nunca de stdin. Vale para las confirmaciones y para
los comandos de creación del modo `trawun y`.

## Decisiones ya tomadas (no las "arregles")

- **Cursor no está en la tabla de asistentes**: su documentación dice que lee
  `.agents/skills/` directamente, así que crearle `.cursor/skills/` sería trabajo inútil.
- **Qoder y Copilot sí están**: usan carpeta propia y no leen la ruta neutral.
- **Copilot se detecta por `.github/skills/`, no por `.github/`**: casi cualquier repo
  tiene `.github/workflows/` sin usar Copilot.
- **No se mueven skills que dejarían ciego a un asistente**: si no lee la ruta neutral y no
  se le van a dejar enlaces, sus skills se quedan donde están y se avisa.
- El porqué de cada cambio está en `CHANGELOG.md`. Léelo antes de tocar comportamiento.

## Antes de commitear y al publicar

```bash
bash pruebas.sh     # verificaciones sobre carpetas temporales; tiene que dar 0 fallos
```

El ritual de publicación completo: subir `VERSION` **en `trawun.sh` y en `instalar.sh`**
(los dos, o el instalador miente), anotar el cambio en `CHANGELOG.md`, commit, tag y push.
Hay pruebas que verifican la coherencia de lo primero y la existencia de lo segundo.

## Estilo

Español en identificadores, comentarios y mensajes; sin tildes ni ñ en nombres de variables
y funciones. Los comentarios explican **por qué**, no qué: el código ya dice qué hace. Las
pruebas se escriben sobre carpetas temporales, nunca sobre un proyecto real.
