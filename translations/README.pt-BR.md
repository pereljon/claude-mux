# claude-mux - Multiplexador do Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sessões persistentes do Claude Code para todos os seus projetos, acessíveis de qualquer lugar pelo aplicativo móvel do Claude.

## Por que

Trabalhar com o Claude Code em múltiplos projetos tem fricção:

- Sessões morrem quando você fecha o terminal
- Sessões do Remote Control não conseguem executar slash commands como `/model` ou `/compact`
- Não é fácil iniciar uma sessão para um projeto que ainda não está rodando
- Trocar modelos, modos de permissão ou compactar contexto pelo celular não é possível

claude-mux resolve tudo isso. Ele envolve o Claude Code no tmux para que as sessões persistam, injeta um system prompt para que o Claude possa gerenciar suas próprias sessões, e roteia slash commands pelo tmux para que funcionem via Remote Control. Uma vez que uma sessão está rodando, você gerencia tudo conversando com o Claude — no terminal ou pelo aplicativo móvel.

## Início Rápido

```bash
./install.sh
```

```bash
claude-mux ~/caminho/para/seu/projeto
```

Pronto. Você está em uma sessão persistente e ciente do contexto, com Remote Control habilitado. A partir daqui, tudo é conversacional.

## Falando com o Claude

É assim que você usa o claude-mux no dia a dia. Cada sessão recebe comandos injetados para que o Claude possa gerenciar sessões, trocar modelos, enviar slash commands e criar novos projetos — tudo de dentro da conversa. Você não precisa memorizar flags de CLI.

```
Você: "status"
Claude: reporta nome da sessão, modelo, modo de permissão, uso de contexto e lista todas as sessões

Você: "listar sessões ativas"
Claude: mostra todas as sessões em execução com seus status

Você: "iniciar uma sessão para o meu projeto api-server"
Claude: lança uma sessão em ~/Claude/work/api-server

Você: "criar um novo projeto chamado mobile-app usando o template web"
Claude: cria o diretório do projeto, inicializa o git, aplica o template, lança uma sessão

Você: "trocar esta sessão para Haiku"
Claude: envia /model haiku para si mesmo via tmux

Você: "compactar a sessão api-server"
Claude: envia /compact para a sessão api-server

Você: "reiniciar a sessão web-dashboard"
Claude: encerra e relança a sessão, preservando o contexto da conversa

Você: "trocar a sessão api-server para o modo plan"
Claude: reinicia a sessão com o modo de permissão plan

Você: "parar todas as sessões"
Claude: encerra graciosamente todas as sessões gerenciadas

Você: "help"
Claude: imprime a lista completa de comandos conversacionais
```

Estes comandos funcionam em qualquer idioma. Se você digitar o equivalente em espanhol, japonês, hebraico ou qualquer outro idioma, o Claude infere a intenção e executa o comando correspondente.

Digite `help` dentro de qualquer sessão para ver a lista completa de comandos.

### Sessão Home

A sessão home é uma sessão de propósito geral que reside no seu diretório base (`~/Claude` por padrão). Ela inicia automaticamente no login quando `LAUNCHAGENT_MODE=home`, dando a você uma sessão do Claude sempre pronta, acessível pelo seu celular. Use-a para gerenciar todas as suas outras sessões sem precisar lançar sessões específicas de projeto primeiro.

A sessão home é sempre **protegida** — `--shutdown home` se recusa a pará-la sem `--force`. Sessões protegidas são marcadas com `*` na saída de status (por exemplo, `active*`).

## O Que Faz

Por baixo dos panos, o claude-mux lida com:

- **Sessões tmux persistentes** com Remote Control habilitado, para que toda sessão fique acessível pelo aplicativo móvel do Claude
- **Retomada de conversa** — retoma a última conversa (`claude -c`) ao relançar, preservando o contexto
- **Injeção de system prompt** — cada sessão recebe comandos para autogerenciamento, roteamento de slash commands e reconhecimento de contas SSH
- **Templates de CLAUDE.md** — mantenha arquivos de template (por exemplo, `web.md`, `python.md`) em `~/.claude-mux/templates/` e aplique-os a novos projetos
- **Suporte a múltiplos coders de CLI** — cria `AGENTS.md` e `GEMINI.md` como symlinks para `CLAUDE.md` para que Codex CLI, Gemini CLI e outras ferramentas compartilhem as mesmas instruções
- **Permissões pré-aprovadas** — adiciona o claude-mux à lista de permissões de cada projeto para que o Claude possa executar comandos de sessão sem solicitar confirmação
- **Migração de processos órfãos** — se o Claude já estiver rodando fora do tmux, migra-o para uma sessão gerenciada
- **Qualidade de vida no tmux** — suporte a mouse, scrollback de 50k, clipboard, 256 cores, teclas estendidas, monitoramento de atividade, títulos de aba

> **Nota:** Isso é diferente de `claude --worktree --tmux`, que cria uma sessão tmux para um worktree git isolado. claude-mux gerencia sessões persistentes para os diretórios reais dos seus projetos, com Remote Control e injeção de system prompt.

## Requisitos

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Instalação

### Homebrew (recomendado)

```bash
brew tap pereljon/tap
brew install claude-mux
```

A configuração (`~/.claude-mux/config`) é criada automaticamente na primeira execução. Para configurar o LaunchAgent (sessão inicial no login), clone o repositório e execute `install.sh`.

Para atualizar:

```bash
brew upgrade claude-mux
```

### Manual

```bash
./install.sh
```

O instalador interativo pergunta onde ficam seus projetos do Claude, se deve iniciar uma sessão home no login e qual modelo usar. Ele instala o `claude-mux` em `~/bin`, cria `~/.claude-mux/config` e configura o LaunchAgent.

Use `--non-interactive` para pular os prompts e aceitar os padrões.

Opções:

```bash
./install.sh --non-interactive                     # pula prompts, usa padrões
./install.sh --base-dir ~/work/claude              # usa um diretório base diferente
./install.sh --launchagent-mode none               # desabilita o comportamento do LaunchAgent
./install.sh --home-model haiku                    # usa Haiku para a sessão home
./install.sh --no-launchagent                      # pula a instalação do LaunchAgent inteiramente
```

O LaunchAgent executa `claude-mux --autolaunch` no login com 45 segundos de atraso para permitir que os serviços do sistema inicializem.

## Status de Sessão

| Status | Significado |
|--------|-------------|
| `active` | a sessão tmux existe, o Claude está em execução e há um cliente tmux local conectado |
| `running` | a sessão tmux existe e o Claude está em execução (sem cliente local conectado) |
| `stopped` | a sessão tmux existe, mas o Claude foi encerrado |
| `idle` | existe um projeto `.claude/` em `BASE_DIR`, mas sem sessão tmux do claude-mux em execução (mostrado apenas com `-L`) |

Um `*` ao final de qualquer status indica que a sessão é protegida e exige `--force` para ser encerrada (por exemplo, `active*`, `running*`). A sessão home é sempre protegida.

Executar `claude-mux` em um diretório que já tem uma sessão em execução conecta-se a ela. Múltiplos terminais podem se conectar à mesma sessão (comportamento padrão do tmux).

## Configuração

Na primeira execução, `~/.claude-mux/config` é criado automaticamente com todas as configurações comentadas. Edite-o para sobrescrever quaisquer padrões — o script nunca precisa ser modificado diretamente.

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `BASE_DIR` | `$HOME/Claude` | Diretório raiz para escanear projetos do Claude (diretórios contendo `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Diretório do arquivo `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Define `permissions.defaultMode` do Claude em cada projeto. Valores válidos: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Defina como `""` para desabilitar. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quando `true`, sessões do Claude podem enviar slash commands a outras sessões — útil para orquestração multiagente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Diretório contendo os arquivos de template CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Template padrão aplicado a novos projetos (`-n`). Defina como `""` para desabilitar. |
| `SLEEP_BETWEEN` | `5` | Segundos entre lançamentos de sessões quando `-a` é usado. Aumente se o registro do RC falhar. |
| `HOME_SESSION_MODEL` | `""` | Modelo da sessão home. Valores válidos: `sonnet`, `haiku`, `opus`. Vazio herda o padrão do Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Lista de arquivos separados por espaço a criar como symlinks para `CLAUDE.md` para outras ferramentas de CLI de IA. Defina como `""` para desabilitar. |
| `LAUNCHAGENT_MODE` | `home` | Comportamento do LaunchAgent no login: `none` (não fazer nada) ou `home` (lançar a sessão home protegida). O legado `LAUNCHAGENT_ENABLED=true` é tratado como `home`. |

**Opções de sessão tmux** (todas configuráveis, todas habilitadas por padrão):

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `TMUX_MOUSE` | `true` | Suporte a mouse — rolar, selecionar, redimensionar painéis |
| `TMUX_HISTORY_LIMIT` | `50000` | Tamanho do buffer de scrollback em linhas (o padrão do tmux é 2000) |
| `TMUX_CLIPBOARD` | `true` | Integração com o clipboard do sistema via OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Tipo de terminal para renderização correta de cores |
| `TMUX_EXTENDED_KEYS` | `true` | Sequências de teclas estendidas, incluindo Shift+Enter (requer tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Atraso da tecla escape em milissegundos (o padrão do tmux é 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Formato de título do terminal/aba (`#S` = nome da sessão, `""` para desabilitar) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notifica quando há atividade em outras sessões |

## Estrutura de Diretórios

Projetos são descobertos pela presença de um diretório `.claude/`, em qualquer profundidade:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ tem .claude/ - gerenciado
│   │   └── .claude/
│   ├── project-b/          # ✓ tem .claude/ - gerenciado
│   │   └── .claude/
│   └── -archived/          # ✗ excluído (começa com -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ tem .claude/ - gerenciado
│   │   └── .claude/
│   ├── .hidden/            # ✗ excluído (diretório oculto)
│   │   └── .claude/
│   └── project-d/          # ✗ sem .claude/ - não é um projeto Claude
├── deep/nested/project-e/  # ✓ tem .claude/ - encontrado em qualquer profundidade
│   └── .claude/
└── ignored-project/        # ✗ excluído (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

Nomes de sessão são derivados dos nomes dos diretórios: espaços viram hifens, caracteres não alfanuméricos (exceto hifens) são substituídos, e hifens iniciais/finais são removidos. Diretórios cujo nome se higieniza para vazio são ignorados com um aviso no log.

## Session System Prompt

Cada sessão do Claude é iniciada com `--append-system-prompt` contendo contexto sobre seu ambiente:

```
You are running inside tmux session '<session-name>'.
claude-mux path: /path/to/claude-mux

Rules:
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session
  via the -s command. Never tell the user you cannot change models or run slash
  commands.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session
- Always print command output verbatim in your response text — never run a
  command silently or rely on tool output being visible
- The 'home' session is a general-purpose session in the base directory, always
  available for managing other sessions. It is protected (* in status):
  --shutdown requires --force, but --restart bypasses protection (it relaunches,
  not permanently kills).
- When asked to shut down sessions, run the command directly — protected sessions
  are skipped automatically, do not ask for confirmation
- When user says: ready — respond with "Ready." on one line. Nothing else.
  Sent automatically when a session starts or restarts.
- When user says: help — print the conversational commands list verbatim
- When user says: status — report session name, current model, current permission
  mode, context usage estimate, then run claude-mux -l and include the results
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: start session SESSION — run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME — run claude-mux --shutdown
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session / restart session NAME — run claude-mux --restart
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: list templates — run claude-mux --list-templates

Commands:
  -s '<session-name>' '/command'  Send slash command to yourself
  -l                          List active sessions
  -L                          List all projects
  -d DIR --no-attach          Launch session in directory
  -n DIR --no-attach          New project
  -n DIR -p --no-attach       New project (create parents)
  --template NAME             CLAUDE.md template (with -n)
  --list-templates            Show available templates
  --shutdown SESSION...       Shut down sessions (omit SESSION to shut down all)
  --shutdown SESSION --force  Shut down protected session
  --restart SESSION...        Restart sessions (omit SESSION to restart all running)
  --permission-mode MODE SESSION  Restart session with a different permission mode
                              Modes: default, acceptEdits, plan, auto, bypassPermissions, dontAsk, dangerously-skip-permissions
                              ("yolo" is an alias for dangerously-skip-permissions)
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

Quando `ALLOW_CROSS_SESSION_CONTROL=true`, o comando de envio muda para permitir mirar qualquer sessão, não apenas a si mesma. O caminho é o caminho absoluto do script no momento do lançamento, então as sessões não dependem do `PATH`.

## Referência de CLI

Você raramente precisa usar estes diretamente — o Claude os executa por você de dentro das sessões. Estão disponíveis para scripting, automação, ou quando você não está dentro de uma sessão.

```bash
# Lançar e conectar
claude-mux                       # inicia o Claude no diretório atual e conecta
claude-mux ~/projetos/meu-app    # inicia o Claude em um diretório e conecta
claude-mux -d ~/projetos/meu-app # mesmo que acima (forma explícita)
claude-mux -t my-app             # conecta a uma sessão tmux existente

# Criar novos projetos
claude-mux -n ~/projetos/app     # cria um novo projeto Claude e conecta
claude-mux -n ~/novo/caminho/app -p  # mesmo que acima, criando o diretório e os pais
claude-mux -n ~/app --template web        # novo projeto com um template CLAUDE.md específico
claude-mux -n ~/app --no-multi-coder      # novo projeto sem symlinks AGENTS.md/GEMINI.md

# Gerenciamento de sessões
claude-mux -l                    # lista sessões por status (active, running, stopped)
claude-mux -L                    # lista todos os projetos (active + idle)
claude-mux -s my-app '/model sonnet'      # envia um slash command para uma sessão
claude-mux --shutdown my-app              # encerra uma sessão específica
claude-mux --shutdown                     # encerra todas as sessões gerenciadas
claude-mux --shutdown home --force        # encerra a sessão home protegida
claude-mux --restart my-app              # reinicia uma sessão específica
claude-mux --restart                     # reinicia todas as sessões em execução
claude-mux --permission-mode plan my-app  # reinicia a sessão em modo plan
claude-mux -a                    # inicia todas as sessões gerenciadas em BASE_DIR

# Outros
claude-mux --list-templates      # mostra os templates CLAUDE.md disponíveis
claude-mux --guide               # mostra os comandos conversacionais para uso dentro das sessões
claude-mux --dry-run             # pré-visualiza ações sem executar
claude-mux --version             # imprime a versão
claude-mux --help                # mostra todas as opções

# Acompanhar o log
tail -f ~/Library/Logs/claude-mux.log
```

Quando executado a partir do terminal, a saída é espelhada em stdout em tempo real. Quando executado via LaunchAgent, a saída vai apenas para o arquivo de log.

## Solução de Problemas

### Sessões mostram "Not logged in · Run /login"

Isso acontece no primeiro lançamento se o keychain do macOS estiver bloqueado (comum quando o script roda antes de o keychain ser desbloqueado após o login). Correção:

```bash
# Desbloqueie o keychain em um terminal comum
security unlock-keychain

# Em seguida, complete a autenticação em uma das sessões em execução
claude-mux -t <any-session>
# Execute /login e complete o fluxo no navegador
```

Após completar a autenticação uma vez, encerre e reinicie todas as sessões — elas vão pegar a credencial armazenada automaticamente.

### Sessões não aparecem no Claude Code Remote

Sessões precisam estar autenticadas (sem mostrar "Not logged in"). Após um lançamento autenticado limpo, elas devem aparecer na lista do RC em poucos segundos.

### Entrada de múltiplas linhas no tmux

O comando `/terminal-setup` não pode rodar dentro do tmux. claude-mux habilita `extended-keys` do tmux por padrão (`TMUX_EXTENDED_KEYS=true`), o que suporta Shift+Enter na maioria dos terminais modernos. Se Shift+Enter não funcionar, use `\` + Return para inserir quebras de linha no seu prompt.

### "Ready." ao iniciar a sessão

Quando uma sessão inicia ou reinicia, o claude-mux envia automaticamente uma mensagem `ready` após o Claude terminar de carregar. A injeção instrui o Claude a responder com "Ready." e nada mais. Isso confirma que a sessão está ativa e a injeção está funcionando.

### Slash commands via Remote Control

Slash commands (por exemplo, `/model`, `/clear`) [não são suportados nativamente](https://github.com/anthropics/claude-code/issues/30674) em sessões RC. claude-mux contorna isso — cada sessão recebe `claude-mux -s` injetado para que o Claude possa enviar slash commands a si mesmo via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` — todas as ações do script com timestamps em UTC (configurável via `LOG_DIR`)

Para depuração de baixo nível do LaunchAgent, use o Console.app ou `log show`.
