# claude-mux - Multiplexador do Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> Nota: Esta tradução pode estar desatualizada em relação ao README em inglês. Consulte [README.md](../README.md) para a versão canônica.

Sessões persistentes do Claude Code para todos os seus projetos, acessíveis de qualquer lugar pelo aplicativo móvel do Claude.

Um shell script que inicia o Claude Code dentro do tmux com Remote Control habilitado, retomada de conversas e autogerenciamento de sessões: listar sessões, enviar slash commands, iniciar novos projetos, encerrar ou reiniciar. Execute `claude-mux` em qualquer diretório para ter uma sessão persistente acessível pelo seu celular.

## Início Rápido

```bash
./install.sh
```

```bash
claude-mux ~/caminho/para/seu/projeto
```

Ou faça `cd` no diretório do seu projeto e execute:

```bash
claude-mux
```

Pronto: você está em uma sessão persistente do Claude, ciente do contexto, com Remote Control habilitado.

claude-mux é um único script bash sem dependências além de tmux e Claude Code.

## O Que Faz

1. **Sessões tmux persistentes com Remote Control** - inicia o Claude Code dentro do tmux com `--remote-control` habilitado, para que toda sessão fique acessível pelo aplicativo móvel do Claude
2. **Retomada de conversas** - se o Claude estava rodando anteriormente no diretório, retoma a última conversa (`claude -c`) dentro de uma nova sessão tmux com Remote Control, preservando seu contexto
3. **Gerenciamento de sessões** - liste sessões active (`-l`) ou todos os projetos, incluindo os idle ainda não iniciados (`-L`), encerre (`--shutdown`), reinicie (`--restart`), troque modos de permissão (`--permission-mode`), conecte (`-t`), envie slash commands para sessões (`-s`)
4. **Autogerenciamento pelo Claude** - cada sessão recebe um system prompt injetado para que o Claude possa executar todos os comandos acima diretamente a partir de prompts de conversa (terminal ou aplicativo móvel):
   - a. Listar sessões em execução e todos os projetos
   - b. Iniciar novas sessões, criar novos projetos
   - c. Enviar slash commands a si mesmo ou a outras sessões (contorno para [slash commands não funcionarem nativamente via RC](https://github.com/anthropics/claude-code/issues/30674))
   - d. Encerrar, reiniciar ou trocar modos de permissão de sessões
5. **Sessão home** - uma sessão leve, sempre em execução, no seu diretório base, iniciada no login (configurável via `LAUNCHAGENT_MODE`). Mantém o Remote Control sempre disponível pelo aplicativo móvel do Claude e pode gerenciar todas as suas outras sessões. Protegida contra encerramento acidental.
6. **Criação de novos projetos** - `claude-mux -n DIRECTORY` cria um projeto pronto para codar com git, `.gitignore` e modo de permissão configurado (`-p` cria o diretório se não existir). Qualquer sessão em execução pode criar novos projetos: peça ao Claude para configurar um repositório em qualquer uma das suas contas do GitHub e comece a codar, de qualquer lugar
7. **Templates de CLAUDE.md** - mantenha uma biblioteca de arquivos de instrução CLAUDE.md em `~/.claude-mux/templates/` (por exemplo, `web.md`, `python.md`, `default.md`) e aplique-os automaticamente a novos projetos. Use `--template NAME` para escolher um template específico ou deixe o padrão ser aplicado
8. **Reconhecimento de contas SSH** - injeta os aliases de host SSH do GitHub a partir de `~/.ssh/config`, para que o Claude saiba quais contas estão disponíveis para operações git
9. **Permissões pré-aprovadas** - claude-mux adiciona a si mesmo à lista de permissões em `.claude/settings.local.json` de cada projeto, para que o Claude possa executar comandos do claude-mux sem solicitar permissão
10. **Migração de processos órfãos** - se o Claude já estiver rodando no diretório de destino fora do tmux, ele é encerrado e relançado dentro de uma sessão tmux gerenciada (a conversa é retomada via `claude -c`)
11. **Qualidade de vida no tmux** - sessões são configuradas com suporte a mouse, buffer de scrollback de 50k, integração com clipboard, 256 cores, atraso de escape reduzido, teclas estendidas (Shift+Enter), monitoramento de atividade e títulos de aba do terminal. Tudo configurável em `~/.claude-mux/config`

> **Nota:** Isto é diferente de `claude --worktree --tmux`, que cria uma sessão tmux para um worktree git isolado. claude-mux gerencia sessões persistentes para os diretórios reais dos seus projetos, com Remote Control e injeção de system prompt.

### Sessão Home

Uma única sessão de propósito geral residindo em `$BASE_DIR`. Iniciada automaticamente no login quando `LAUNCHAGENT_MODE=home`, ou manualmente ao executar `claude-mux` a partir de `$BASE_DIR`. Garante uma sessão do Claude sempre pronta, acessível pelo seu celular, sem precisar iniciar sessões para todos os projetos.

A sessão home é sempre **protegida**: `--shutdown home` se recusa a pará-la sem `--force`, independentemente de como foi iniciada. Sessões protegidas são marcadas com `*` na saída de `-l`/`-L` (por exemplo, `active*`).

## Requisitos

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Instalação

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

## Uso

```bash
claude-mux                       # inicia o Claude no diretório atual e conecta
claude-mux ~/projects/my-app     # inicia o Claude em um diretório e conecta
claude-mux -d ~/projects/my-app  # mesmo que acima (forma explícita)
claude-mux -a                    # inicia todas as sessões gerenciadas em BASE_DIR
claude-mux -n ~/projects/app     # cria um novo projeto Claude e conecta
claude-mux -n ~/new/path/app -p  # mesmo que acima, criando o diretório e os pais
claude-mux -n ~/app --template web  # novo projeto com um template CLAUDE.md específico
claude-mux --list-templates      # mostra os templates de CLAUDE.md disponíveis
claude-mux -t my-app             # conecta a uma sessão tmux existente
claude-mux -s my-app '/model sonnet' # envia um slash command para uma sessão
claude-mux -l                    # lista sessões por status (active, running, stopped)
claude-mux -L                    # lista todos os projetos (active + idle)
claude-mux --shutdown            # encerra graciosamente todas as sessões gerenciadas do Claude
claude-mux --shutdown my-app     # encerra uma sessão específica
claude-mux --shutdown a b c      # encerra múltiplas sessões
claude-mux --shutdown home --force  # encerra a sessão home protegida
claude-mux --restart             # reinicia sessões que estavam em execução
claude-mux --restart my-app      # reinicia uma sessão específica
claude-mux --restart a b c       # reinicia múltiplas sessões
claude-mux --permission-mode plan my-app    # reinicia a sessão em modo plan
claude-mux --permission-mode dangerously-skip-permissions my-app  # modo yolo
claude-mux --dry-run             # pré-visualiza ações sem executar
claude-mux --version             # imprime a versão
claude-mux --help                # mostra todas as opções
claude-mux --guide               # mostra comandos conversacionais para uso dentro de sessões

# Acompanhar o log
tail -f ~/Library/Logs/claude-mux.log
```

Quando executado a partir do terminal, a saída é espelhada em stdout em tempo real. Quando executado via LaunchAgent, a saída vai apenas para o arquivo de log.

## Status de Sessão

| Status | Significado |
|--------|---------|
| `active` | a sessão tmux existe, o Claude está em execução e há um cliente tmux local conectado |
| `running` | a sessão tmux existe e o Claude está em execução (sem cliente local conectado) |
| `stopped` | a sessão tmux existe, mas o Claude foi encerrado |
| `idle` | existe um projeto `.claude/` em `BASE_DIR`, mas sem sessão tmux do claude-mux em execução (mostrado apenas com `-L`) |

Um `*` ao final de qualquer status indica que a sessão é protegida e exige `--force` para ser encerrada (por exemplo, `active*`, `running*`). A sessão home é sempre protegida.

Executar `claude-mux` em um diretório que já tem uma sessão em execução conecta-se a ela. Múltiplos terminais podem se conectar à mesma sessão (comportamento padrão do tmux).

## Exemplos de Prompts ao Claude

Como cada sessão recebe os comandos do claude-mux injetados, você pode gerenciar sessões diretamente a partir de prompts de conversa, no terminal ou pelo aplicativo móvel:

```
Você: "Quais sessões estão em execução?"
Claude: executa `claude-mux -l` e exibe os resultados

Você: "Mostre todos os projetos"
Claude: executa `claude-mux -L` e exibe os resultados

Você: "Inicie uma sessão para o meu projeto de trabalho api-server"
Claude: executa `claude-mux -d ~/Claude/work/api-server --no-attach`

Você: "Crie um novo projeto pessoal chamado mobile-app"
Claude: executa `claude-mux -n ~/Claude/personal/mobile-app -p --no-attach`

Você: "Quais templates eu tenho?"
Claude: executa `claude-mux --list-templates` e exibe os resultados

Você: "Crie um novo projeto de trabalho chamado api-server usando o template web"
Claude: executa `claude-mux -n ~/Claude/work/api-server -p --template web --no-attach`

Você: "Mude todas as sessões para Sonnet"
Claude: executa `claude-mux -s SESSION '/model sonnet'` para cada sessão em execução

Você: "Encerre a sessão data-pipeline"
Claude: executa `claude-mux --shutdown data-pipeline`

Você: "Reinicie a sessão travada web-dashboard"
Claude: executa `claude-mux --restart web-dashboard`

Você: "Mude a sessão api-server para o modo plan"
Claude: executa `claude-mux --permission-mode plan api-server`

Você: "Coloque a sessão data-pipeline em modo yolo"
Claude: executa `claude-mux --permission-mode dangerously-skip-permissions data-pipeline`

Você: "Inicie a sessão data-pipeline em segundo plano"
Claude: executa `claude-mux -d ~/Claude/work/data-pipeline --no-attach`

Você: "Inicie todos os meus projetos"
Claude: executa `claude-mux -a` (após confirmação: isto inicia cada projeto gerenciado)
```

## Configuração

Na primeira execução, `~/.claude-mux/config` é criado automaticamente, com todas as configurações comentadas. Edite-o para sobrescrever quaisquer padrões: o script nunca precisa ser modificado diretamente.

| Variável | Padrão | Descrição |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Diretório raiz para escanear projetos do Claude (diretórios contendo `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Diretório do arquivo `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Define `permissions.defaultMode` do Claude em cada projeto. Valores válidos: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Defina como `""` para desabilitar. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quando `true`, sessões do Claude podem enviar slash commands a outras sessões: útil para orquestração multiagente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Diretório contendo os arquivos de template CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Template padrão aplicado a novos projetos (`-n`). Defina como `""` para desabilitar. |
| `SLEEP_BETWEEN` | `5` | Segundos entre lançamentos de sessões quando `-a` é usado. Aumente se o registro do RC falhar. |
| `HOME_SESSION_MODEL` | `""` | Modelo da sessão home. Valores válidos: `sonnet`, `haiku`, `opus`. Vazio herda o padrão do Claude. |
| `LAUNCHAGENT_MODE` | `home` | Comportamento do LaunchAgent no login: `none` (não fazer nada) ou `home` (lançar a sessão home protegida). O legado `LAUNCHAGENT_ENABLED=true` é tratado como `home`. |

**Opções de sessão tmux** (todas configuráveis, todas habilitadas por padrão):

| Variável | Padrão | Descrição |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | Suporte a mouse: rolar, selecionar, redimensionar painéis |
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

Nomes de sessão são derivados dos nomes dos diretórios: espaços viram hifens, caracteres não alfanuméricos (exceto hifens) são substituídos, e hifens iniciais/finais são removidos. Diretórios cujo nome se higieniza para vazio são ignorados, com um aviso no log.

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

Após completar a autenticação uma vez, encerre e reinicie todas as sessões: elas vão pegar a credencial armazenada automaticamente.

### Sessões não aparecem no Claude Code Remote

Sessões precisam estar autenticadas (sem mostrar "Not logged in"). Após um lançamento autenticado limpo, elas devem aparecer na lista do RC em poucos segundos.

### Entrada de múltiplas linhas no tmux

O comando `/terminal-setup` não pode rodar dentro do tmux. claude-mux habilita `extended-keys` do tmux por padrão (`TMUX_EXTENDED_KEYS=true`), o que suporta Shift+Enter na maioria dos terminais modernos. Se Shift+Enter não funcionar, use `\` + Return para inserir quebras de linha no seu prompt.

### Slash commands via Remote Control

Slash commands (por exemplo, `/model`, `/clear`) [não são suportados nativamente](https://github.com/anthropics/claude-code/issues/30674) em sessões RC. claude-mux contorna isso: cada sessão recebe `claude-mux -s` injetado para que o Claude possa enviar slash commands a si mesmo via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` - todas as ações do script com timestamps em UTC (configurável via `LOG_DIR`)

Para depuração de baixo nível do LaunchAgent, use o Console.app ou `log show`.
