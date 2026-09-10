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

El ritual completo, en orden:

1. `bash pruebas.sh` — verificaciones sobre carpetas temporales; 0 fallos
2. Subir `VERSION` **en `trawun.sh` y en `instalar.sh`** (los dos, o el instalador miente)
3. Anotar el cambio en `CHANGELOG.md`
4. Commit, push, `git tag -a vX.Y.Z -m "vX.Y.Z — qué cambió"` y push del tag
5. Publicar la página del release. Sin este paso el tag existe, pero quien visita el repo no
   ve ninguna versión: la URL fijada funciona y la sección de Releases está vacía.

```bash
awk -v ver=vX.Y.Z '$0 ~ "^## " ver "($| )" {dentro=1; next} /^## / {dentro=0} dentro' \
    CHANGELOG.md > /tmp/notas.md
gh release create vX.Y.Z --title "vX.Y.Z — qué cambió" --notes-file /tmp/notas.md
```

Los pasos 2 y 3 tienen prueba que los vigila. **Cuándo NO hay release**: cambios solo de
pruebas o documentación — si `trawun.sh` no cambió, quien lo tenga instalado no gana nada
actualizando, y un tag de más ensucia el historial.

## Estilo

Español en identificadores, comentarios y mensajes; sin tildes ni ñ en nombres de variables
y funciones. Los comentarios explican **por qué**, no qué: el código ya dice qué hace. Las
pruebas se escriben sobre carpetas temporales, nunca sobre un proyecto real.
