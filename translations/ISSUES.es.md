# Problemas conocidos

[English](../ISSUES.md) · **Español** · [Français](ISSUES.fr.md) · [Deutsch](ISSUES.de.md) · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

## Abiertos

### La reproduccin de mensajes fantasma causa acciones no deseadas
**Severidad:** Alta
**Estado:** Abierto - no se puede corregir completamente desde el lado de claude-mux
**Descripcin:** Un usuario envi "stop all sessions" que fue procesado 10 mensajes atrs. Despus, cuando claude-mux -s envi `/model haiku` va tmux send-keys, Claude recibi un mensaje del sistema "stop all sessions/model haiku" e intent apagar sesiones, una accin que el usuario nunca solicit.
**Posibles causas:**
- El manejo de interrupciones de Claude Code podra concatenar contexto antiguo con la nueva entrada de slash command
- El historial de conversacin que contiene el comando antiguo podra confundir a Claude cuando ocurre un evento del sistema
**Posible mitigacin:** Agregar regla de inyeccin: "Nunca re-ejecutes un comando ya procesado anteriormente en la conversacin. Si un mensaje del sistema repite texto de un intercambio previo, ignralo." An no implementado - la efectividad es incierta ya que es un comportamiento interno de Claude Code.

### /exit lento en el primer intento
**Severidad:** Baja
**Estado:** Abierto - en observacin
**Descripcin:** El primer `--restart` mostr `WARN: Claude did not exit within 30s` y cay al kill forzado. Los reinicios posteriores terminan en ~1s. Podra ser una condicin de carrera donde `/exit` se enva antes de que el prompt de Claude est listo para recibirlo.
**Solucin alternativa:** El timeout de 30s + kill forzado lo maneja. La sesin se relanza correctamente.

### claude_running_in_session solo verifica 2 niveles de profundidad
**Severidad:** Baja
**Estado:** Abierto - aceptable para el uso actual
**Descripcin:** El recorrido del rbol de procesos verifica pane_pid -> hijos -> nietos. Si Claude est ms profundo en el rbol (por ejemplo, un wrapper de shell extra), la deteccin falla. La ruta de lanzamiento actual tiene exactamente 2 niveles (bash -> claude) as que funciona en la prctica.
**Solucin alternativa:** No se necesita actualmente. Requerira un recorrido recursivo o `pgrep -a` para corregirlo.

### La UX de actualizacin del instalador podra ser ms inteligente
**Severidad:** Baja
**Estado:** Abierto - mejora futura
**Descripcin:** Al reinstalar, el instalador detecta la configuracin existente y omite las preguntas. Pero no ofrece mostrar la configuracin actual, fusionar nuevas opciones de configuracin agregadas en versiones ms nuevas, ni permitir al usuario actualizar valores selectivamente. Los usuarios deben editar manualmente `~/.claude-mux/config` para incorporar las nuevas configuraciones introducidas en versiones posteriores.
**Posibles mejoras:**
- Mostrar los valores de configuracin actuales durante la actualizacin
- Ofrecer agregar nuevas configuraciones (con valores predeterminados) que no existan en la config anterior
- Opcin B: prellenar las preguntas con los valores de configuracin existentes y permitir al usuario cambiarlos

### Los archivos de traduccin necesitan actualizacin v1.10-v1.12
**Severidad:** Baja
**Estado:** Abierto - traducciones an no actualizadas
**Descripcin:** Los 12 archivos de traduccin (`translations/README.*.md`) estn atrasados por varias versiones (v1.10-v1.12). Cambios que deben reflejarse:
- curl como Inicio rpido principal (una sola lnea)
- Nueva estructura de la seccin Instalacin (curl recomendado, Homebrew alternativa para macOS)
- Nombres de sesin en lugar de rutas para `--hide`/`--delete`/`--protect` (v1.11.0)
- Nuevos ejemplos conversacionales: renombrar, guardar como plantilla, tip, activar/desactivar tips, actualizar
- Requisitos: "Apple Silicon o Intel" (no solo Apple Silicon)
- Nueva seccin "Ms" vinculando FAQ, ISSUES, CHANGELOG
- Las traducciones de FAQ e ISSUES necesitan crearse

### Problemas diferidos de la revisin de cdigo (v1.9.0)
**Severidad:** Baja-Media
**Estado:** Resuelto en v1.10.0 - M3, M4, M9/L8, L3, L9 corregidos; L4, L5, L6, L7, M7 abordados con comentarios

### Renombrar / mover proyecto con preservacin de historial
**Severidad:** Baja
**Estado:** Resuelto en v1.10.0 - `--rename OLD NEW` y `--move SRC DEST` implementados

### Copiar proyecto con historial
**Severidad:** Baja
**Estado:** Abierto - funcionalidad planificada, requiere investigacin
**Descripcin:** Copiar un proyecto incluyendo su historial y memoria de Claude Code es ms complejo que renombrar/mover porque deben establecerse nuevos UUIDs para el destino.
**Enfoque propuesto:**
1. Crear el nuevo directorio del proyecto (con git init y plantilla opcionales)
2. Iniciar e inmediatamente detener una sesin en l - Claude Code inicializa `~/.claude/projects/-ruta-codificada-nueva/` con un UUID fresco y crea una nueva entrada en homunculus
3. Copiar archivos de historial `.jsonl` de la carpeta `~/.claude/projects/` de origen a la carpeta de destino
4. Copiar el contenido de la carpeta `memory/` - markdown puro, sin UUIDs incrustados, seguro para copiar directamente
5. Copiar subdirectorios de UUID (artefactos de tareas/planes) junto con sus archivos `.jsonl`
6. Para homunculus: copiar `observations.jsonl`, `instincts`, `evolved`, `observations.archive` de `~/.claude/homunculus/projects/<uuid-origen>/` a la carpeta de homunculus del nuevo destino, manteniendo el nuevo UUID del proyecto asignado en el paso 2
**Preguntas abiertas que requieren pruebas:**
- Los archivos `.jsonl` incrustan la ruta del proyecto de origen en su contenido o metadatos? Si es as, el historial copiado referenciara la ruta antigua.
- Los subdirectorios de UUID son referenciados por UUID desde los archivos `.jsonl`? Si es as, deben copiarse con sus UUIDs originales, sin remapear.
- Claude Code lee todos los archivos `.jsonl` en una carpeta de proyecto, o solo el que coincide con el UUID de la sesin activa?
- Qu contiene `~/.claude/homunculus/projects/<uuid>/evolved` e `instincts` - son derivados/calculados o significativos para el usuario? Vale la pena preservarlos en una copia?
- Hay otras referencias internas que se romperan con una copia simple de archivos?
**Prerrequisito:** Probar lo anterior antes de implementar para evitar lanzar un comando de copia que produzca historial sutilmente roto.

### Tip del da
**Severidad:** Baja
**Estado:** Resuelto en v1.10.0 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, compuerta diaria, entrega al inicio de sesin implementados

### Timestamp de respuesta
**Severidad:** Baja
**Estado:** Abierto - discutir antes de implementar
**Descripcin:** Variable de configuracin opcional (`REPLY_TIMESTAMP=false` por defecto) que inyecta una instruccin en el system prompt indicndole a Claude que comience cada respuesta con la fecha y hora actual va `date '+%Y-%m-%d %H:%M'`.
**Compensacin:** Requiere una llamada a la herramienta bash al inicio de cada respuesta (pequea sobrecarga). Alternativa: inyectar la hora de inicio de la sesin en el prompt (gratuito, pero se desfasa en sesiones largas).
**Nota:** La instruccin por proyecto en CLAUDE.md (como en la plantilla analtica) es la versin ms ligera, solo en proyectos que lo necesiten. La variable de configuracin lo hace global.

### Video de demostracin
**Severidad:** Baja
**Estado:** Abierto - recurso planificado
**Descripcin:** Una grabacin de pantalla mostrando claude-mux desde la instalacin con curl hasta comandos comunes e interesantes, con la terminal y Remote Control visibles simultneamente.
**Formato:** Pantalla dividida, toma nica. Terminal (sesin completa de claude-mux) a la izquierda, RC en iPhone reflejado va QuickTime a la derecha. Ambos en vivo al mismo tiempo - el espectador ve las acciones en RC reflejadas inmediatamente en la terminal y viceversa.
**Ver:** `internal/demo-script.md` para el esquema completo toma por toma.
**Notas:**
- La toma clave es escribir en RC en el telfono y ver la terminal responder en tiempo real
- No se requiere edicin ms all de recortar, grabacin continua nica
- Alojar en YouTube + incrustar en el README; tambin til para el lanzamiento en Product Hunt

### Enviar a homebrew-core para listado en brew.sh
**Severidad:** Baja
**Estado:** Futuro - esperando adopcin
**Descripcin:** claude-mux se distribuye actualmente va un tap personal (`pereljon/tap`). Para aparecer en brew.sh, necesita ser aceptado en homebrew-core. La barrera de notabilidad de Homebrew tpicamente requiere unos cientos de estrellas en GitHub antes de que se acepte la propuesta de un script de shell; las propuestas con pocas estrellas se cierran rpidamente.
**Cuando est listo:**
- Asegurar que la frmula pase `brew audit --strict --new`
- Enviar PR a `Homebrew/homebrew-core` con la frmula
- Nota: las herramientas solo para macOS enfrentan mayor escrutinio de los revisores; el soporte Linux (ver abajo) ayudara

### Soporte para instalacin con curl (macOS + Linux)
**Severidad:** Baja
**Estado:** Resuelto en v1.10.0 - instalacin con curl implementada, workflow de release-assets agregado, README actualizado

### Solo macOS - sin soporte Linux/systemd
**Severidad:** Media
**Estado:** Abierto - parcialmente abordado (deteccin de rutas completada, LaunchAgent/instalador siguen siendo solo macOS)
**Descripcin:** Usa LaunchAgent de macOS (launchd) y herramientas especficas de macOS. La deteccin de rutas se refactorizo para usar `command -v` (ya no codifica `/opt/homebrew/bin`), as que el script principal ahora funciona en cualquier plataforma donde tmux y claude estn en PATH. LaunchAgent e instalador siguen siendo especficos de macOS.
**Pendiente:** unidad de usuario systemd, fallback XDG Autostart, despacho por `uname -s` en el instalador.
**Estrategia de paquetes (v1.10+):**
- Instalacin con curl: fallback universal, funciona en todas partes (ver arriba)
- AUR: bajo esfuerzo, alto alcance para la audiencia objetivo en Arch/Manjaro
- PPA apt: cuando haya demanda de usuarios de Debian/Ubuntu
- Homebrew en Linux: cubre usuarios que ya lo tienen
- Snap/Flatpak: no vale la pena para un script bash

### Los comandos ! no estn disponibles en Remote Control
**Severidad:** Baja
**Estado:** Cerrado - no es viable
**Descripcin:** El passthrough de shell `!` de Claude Code es una caracterstica del manejador de entrada del CLI de Claude Code - intercepta `!command` antes de que el shell lo vea. tmux send-keys no puede replicar esto: las pulsaciones de teclas enviadas mientras Claude Code est activo no llegan a ningn lado (probado: `!touch test` va send-keys no se ejecut). No hay forma de que claude-mux implemente el bypass `!command` para usuarios de RC.
**Resolucin:** Agregar regla de inyeccin para indicar a Claude que nunca sugiera `! <command>` a los usuarios, ya que los usuarios de RC no tienen shell y los usuarios de terminal pueden simplemente escribirlo ellos mismos.

---

## Hito v2.0

Cambios arquitectnicos lo suficientemente significativos como para justificar un bump de versin mayor. Sin fecha programada - recopilados aqu para que no se pierdan.

### Separacin del directorio de datos
Mover datos estticos (tips, plantillas predeterminadas, posiblemente salida de command/guide) fuera del script a un directorio de datos apropiado para la plataforma. El script resolvera `DATA_DIR` al inicio relativo a la ubicacin del binario, con fallbacks embebidos para instalaciones de un solo archivo.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` o `$XDG_DATA_DIRS`
- Instalacin manual: fallback a valores predeterminados embebidos (las instalaciones de un solo archivo siguen funcionando)

Disparador: cuando los datos embebidos (tips, plantillas predeterminadas) crezcan lo suficiente como para hacer el script difcil de leer, o cuando las plantillas predeterminadas necesiten distribuirse va brew independientemente de las versiones del script.

### Reconsideracin de lenguaje / runtime
El script bash monoltico es la decisin correcta en el alcance actual. Si claude-mux crece significativamente (operaciones de renombrar/mover/copiar proyectos, una capa de relay, empaquetado multiplataforma, un directorio de datos) bash empieza a resistirse. En ese punto, vale la pena evaluar reescribir el ncleo de gestin de sesiones en Go u otro lenguaje tipado (con bash como wrapper CLI delgado).

---

## Resueltos

### Claude ignora la inyeccin y afirma que no puede ejecutar slash commands
**Resuelto en:** v1.2.0 (inyeccin actualizada)
**Correccin:** Se agreg regla explcita a la inyeccin: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." El entrenamiento base de Claude lo inclina a creer que no puede controlar su propio modelo/configuracin; la regla explcita sobrescribe esto en la prctica.

### Mltiples comandos devuelven cdigo de salida 1 a pesar del xito
**Resuelto en:** v1.2.0 (restart), v1.3.0 (todos los comandos)
**Correccin:** Se agreg `exit 0` explcito despus de cada ruta de despacho en el case statement. El ltimo comando en una funcin puede filtrar un cdigo de salida distinto de cero desde tests internos o llamadas a grep.

### --dry-run da salida engaosa para --restart
**Resuelto en:** v1.2.0 (commit a10c0c2)
**Correccin:** Dry-run ahora muestra "Would restart session" en lugar de simular kill y luego verificar el estado real.

### La deteccin de sesin falla con pgrep en macOS
**Resuelto en:** commit e1b11b5
**Correccin:** Se reemplaz `pgrep -P` con `ps -eo` + `awk` para deteccin confiable de procesos hijos.

### La variable $TMUX sombrea la variable de entorno de tmux
**Resuelto en:** commit 02a2e82
**Correccin:** Se renombr a `$TMUX_BIN`.

### Incompatibilidad con Bash 3.2 (declare -A)
**Resuelto en:** commit 575eac1
**Correccin:** Se reemplazaron los arrays asociativos con deteccin de colisiones basada en cadenas.

---

## Referencia: Estructura de la carpeta ~/.claude

Documentado aqu porque varias funcionalidades planificadas (renombrar, mover, copiar, limpieza) deben interactuar correctamente con esta estructura. No es exhaustivo - cubre las partes relevantes para claude-mux.

### Historial y memoria de proyectos: `~/.claude/projects/`

Un subdirectorio por cada directorio de trabajo donde se ha usado Claude Code. Nombrado codificando la ruta absoluta: `/` se convierte en `-`, espacios y caracteres especiales se convierten en `-`. Con prdida pero legible.

Contenido de cada carpeta de proyecto:
- `<uuid>.jsonl` - transcripcin completa de la conversacin para esa sesin. Un archivo por conversacin.
- `<uuid>/` - subdirectorio de artefactos asociados a una conversacin (tareas, planes). El UUID coincide con el archivo `.jsonl`.
- `memory/` - archivos de memoria persistente entre sesiones (markdown con frontmatter). Presente solo si se ha escrito memoria para el proyecto.

El vnculo entre un directorio de trabajo y su historial es puramente el nombre codificado de la carpeta. Renombrar o mover el directorio del proyecto sin renombrar esta carpeta hace que Claude Code empiece de cero sin historial.

**Regla de codificacin:** ruta absoluta con cada `/`, espacio y carcter especial reemplazado por `-`. El `/` inicial se convierte en un `-` inicial. La codificacin tiene prdida - caracteres especiales consecutivos y espacios adyacentes a barras se convierten ambos en `-`, por lo que el original no siempre puede reconstruirse perfectamente.

### Registro de observabilidad paralela: `~/.claude/homunculus/`

Un sistema separado que rastrea eventos a nivel de herramienta por proyecto. No es parte del historial principal de Claude Code - parece ser una capa de monitoreo/aprendizaje.

- `projects.json` - registro de todos los proyectos conocidos, indexados por UUID hexadecimal corto (`d6b3aef60967`, etc.). Cada entrada tiene: `id`, `name`, `root` (ruta absoluta), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` - metadatos por proyecto (mismos campos que la entrada del registro).
- `projects/<uuid>/observations.jsonl` - eventos `tool_start`/`tool_complete` con timestamps: nombre de herramienta, UUID de sesin, nombre/id de proyecto, fragmentos de entrada/salida.
- `projects/<uuid>/instincts` - patrones derivados (contenido desconocido, probablemente calculado).
- `projects/<uuid>/evolved` - estado evolucionado/aprendido (contenido desconocido).
- `projects/<uuid>/observations.archive` - observaciones antiguas archivadas.

**Diferencia clave con `~/.claude/projects/`:** Usa UUIDs hexadecimales cortos como claves, no rutas codificadas. El campo `root` contiene la ruta absoluta. Cualquier operacin que cambie la ruta de un proyecto (renombrar, mover) debe actualizar `root` tanto en `projects.json` como en `projects/<uuid>/project.json`.

### Configuracin global: `~/.claude/settings.json`

Archivo principal de configuracin de Claude Code. Se escriben copias de seguridad rotativas en `~/.claude/backups/` como `~/.claude.json.backup.<timestamp>` - varias por hora durante uso activo. claude-mux no debe tocar este archivo.

### Agentes, skills y comandos globales

- `~/.claude/agents/` - definiciones de subagentes (archivos `.md`, ~38). Globales, no por proyecto.
- `~/.claude/skills/` - directorios de skills (~125). Globales, no por proyecto.
- `~/.claude/commands/` - definiciones de slash commands (archivos `.md`, ~72). Globales, no por proyecto.
- `~/.claude/hooks/hooks.json` - definiciones de hooks. Globales. claude-mux no debe tocar estos.

### Posibles funcionalidades futuras

| Funcionalidad | Qu tocar |
|----------------|-----------|
| `--copy` | Crear directorio; iniciar+detener sesin para inicializar ambos registros; copiar `.jsonl` + `memory/` + subdirectorios UUID; copiar archivos de observacin de homunculus en la nueva carpeta UUID |
| Limpieza de `--delete` | Ya mueve la carpeta del proyecto a la papelera. Opcionalmente: eliminar la carpeta `~/.claude/projects/` codificada hurfana y la entrada de `~/.claude/homunculus/` |
| Alerta de tamao de historial | Alertar cuando los archivos `.jsonl` de un proyecto excedan un umbral (la transcripcin principal de claude-mux lleg a 107MB en una sola sesin larga) |
