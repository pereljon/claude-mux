# Problemas Conhecidos

[English](../ISSUES.md) · [Español](ISSUES.es.md) · [Français](ISSUES.fr.md) · [Deutsch](ISSUES.de.md) · **Português** · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

## Abertos

### Replay de mensagem fantasma causa ações não intencionais
**Severidade:** Alta
**Status:** Aberto - não é possível corrigir completamente do lado do claude-mux
**Descrição:** Um usuário enviou "stop all sessions", que foi tratado 10 mensagens antes. Depois, quando `claude-mux -s` enviou `/model haiku` via tmux send-keys, o Claude recebeu uma mensagem de sistema "stop all sessions/model haiku" e tentou encerrar sessões, uma ação que o usuário nunca solicitou.
**Possíveis causas:**
- O tratamento de interrupções do Claude Code pode concatenar contexto antigo com nova entrada de slash command
- O histórico da conversa contendo o comando antigo pode confundir o Claude quando um evento de sistema ocorre
**Possível mitigação:** Adicionar regra de injeção: "Nunca reexecute um comando já tratado anteriormente na conversa. Se uma mensagem de sistema repetir texto de uma troca anterior, ignore-a." Ainda não implementado: eficácia incerta já que é um comportamento interno do Claude Code.

### /exit lento na primeira tentativa
**Severidade:** Baixa
**Status:** Aberto - monitorando
**Descrição:** O primeiro `--restart` gerou `WARN: Claude did not exit within 30s` e caiu para hard kill. Reinícios subsequentes encerram em ~1s. Pode ser uma condição de corrida onde `/exit` é enviado antes do prompt do Claude estar pronto para recebê-lo.
**Contorno:** O timeout de 30s + hard kill resolve. A sessão relança corretamente.

### claude_running_in_session só verifica 2 níveis de profundidade
**Severidade:** Baixa
**Status:** Aberto - aceitável para o uso atual
**Descrição:** A caminhada pela árvore de processos verifica pane_pid -> filhos -> netos. Se o Claude estiver mais profundo na árvore (por exemplo, wrapper de shell extra), a detecção falha. O caminho de lançamento atual tem exatamente 2 níveis (bash -> claude), então funciona na prática.
**Contorno:** Nenhum necessário atualmente. Seria necessária uma caminhada recursiva ou `pgrep -a` para corrigir.

### UX de upgrade do instalador poderia ser mais inteligente
**Severidade:** Baixa
**Status:** Aberto - melhoria futura
**Descrição:** Na reinstalação, o instalador detecta config existente e pula os prompts. Mas não oferece mostrar as configurações atuais, mesclar novas opções de config adicionadas em versões mais recentes, ou deixar o usuário atualizar valores seletivamente. Usuários precisam editar manualmente `~/.claude-mux/config` para adotar novas configurações introduzidas em versões posteriores.
**Melhorias potenciais:**
- Mostrar valores atuais de config durante upgrade
- Oferecer adicionar novas configurações (com padrões) que não existiam no config antigo
- Opção B: pré-preencher prompts com valores existentes e permitir que o usuário os altere

### Arquivos de tradução precisam de atualização v1.10-v1.12
**Severidade:** Baixa
**Status:** Aberto - traduções ainda não atualizadas
**Descrição:** Todos os 12 arquivos de tradução (`translations/README.*.md`) estão desatualizados em várias versões (v1.10-v1.12). Mudanças que precisam ser refletidas:
- curl como Quick Start principal (uma linha)
- Nova estrutura da seção de instalação (curl recomendado, Homebrew alternativa macOS)
- Nomes de sessão em vez de caminhos para `--hide`/`--delete`/`--protect` (v1.11.0)
- Novos exemplos conversacionais: rename, save-as-template, tip, enable/disable tips, update
- Requisitos: "Apple Silicon ou Intel" (não só Apple Silicon)
- Nova seção "Mais" linkando FAQ, ISSUES, CHANGELOG
- Traduções de FAQ e ISSUES precisam ser criadas

### Problemas adiados do code review (v1.9.0)
**Severidade:** Baixa-Média
**Status:** Resolvido na v1.10.0 - M3, M4, M9/L8, L3, L9 corrigidos; L4, L5, L6, L7, M7 tratados com comentários

### Renomear / mover projeto com preservação de histórico
**Severidade:** Baixa
**Status:** Resolvido na v1.10.0 - `--rename OLD NEW` e `--move SRC DEST` implementados

### Cópia de projeto com histórico
**Severidade:** Baixa
**Status:** Aberto - funcionalidade planejada, requer investigação
**Descrição:** Copiar um projeto incluindo seu histórico e memória do Claude Code é mais complexo que renomear/mover porque novos UUIDs precisam ser estabelecidos para o destino.
**Abordagem proposta:**
1. Criar o novo diretório do projeto (com git init e template opcionais)
2. Iniciar e imediatamente parar uma sessão nele: o Claude Code inicializa `~/.claude/projects/-encoded-new-path/` com um UUID novo e cria uma nova entrada no homunculus
3. Copiar arquivos de histórico `.jsonl` da pasta `~/.claude/projects/` de origem para a pasta de destino
4. Copiar o conteúdo da pasta `memory/`: markdown puro, sem UUIDs embutidos, seguro para copiar diretamente
5. Copiar subdiretórios UUID (artefatos de task/plan) junto com seus arquivos `.jsonl`
6. Para o homunculus: copiar `observations.jsonl`, `instincts`, `evolved`, `observations.archive` de `~/.claude/homunculus/projects/<src-uuid>/` para a pasta homunculus do novo destino, mantendo o UUID do novo projeto atribuído no passo 2
**Questões abertas que requerem teste:**
- Arquivos `.jsonl` embutem o caminho do projeto de origem em seu conteúdo ou metadados? Se sim, o histórico copiado referenciaria o caminho antigo.
- Subdiretórios UUID são referenciados por UUID de dentro dos arquivos `.jsonl`? Se sim, precisam ser copiados com seus UUIDs originais, sem remapeamento.
- O Claude Code lê todos os arquivos `.jsonl` em uma pasta de projeto, ou apenas o que corresponde ao UUID da sessão ativa?
- O que `~/.claude/homunculus/projects/<uuid>/evolved` e `instincts` contêm: são derivados/computados ou significativos para o usuário? Vale a pena preservar em uma cópia?
- Há outras referências internas que quebrariam uma cópia de arquivos ingênua?
**Pré-requisito:** Testar o acima antes de implementar para evitar entregar um comando de cópia que produz histórico sutilmente quebrado.

### Dica do dia
**Severidade:** Baixa
**Status:** Resolvido na v1.10.0 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, trava diária, entrega no início da sessão implementados

### Timestamp de resposta
**Severidade:** Baixa
**Status:** Aberto - discutir antes de implementar
**Descrição:** Variável de config opcional (`REPLY_TIMESTAMP=false` padrão) que injeta uma instrução no system prompt dizendo ao Claude para iniciar cada resposta com a data e hora atual via `date '+%Y-%m-%d %H:%M'`.
**Tradeoff:** Requer uma chamada de ferramenta bash no início de cada resposta (overhead pequeno). Alternativa: injetar o horário de início da sessão no prompt (gratuito, mas desatualiza em sessões longas).
**Nota:** Instrução por projeto no CLAUDE.md (como no template analítico) é a versão mais leve: só em projetos que querem. A variável de config torna global.

### Vídeo de demonstração
**Severidade:** Baixa
**Status:** Aberto - asset planejado
**Descrição:** Uma gravação de tela mostrando o claude-mux da instalação via curl até comandos comuns e interessantes, com terminal e Remote Control visíveis simultaneamente.
**Formato:** Tela dividida, tomada única. Terminal (sessão claude-mux completa) à esquerda, RC no iPhone espelhado via QuickTime à direita. Ambos ao vivo ao mesmo tempo: o espectador vê ações no RC imediatamente refletidas no terminal e vice-versa.
**Veja:** `internal/demo-script.md` para o roteiro completo tomada a tomada.
**Notas:**
- A tomada-chave é digitar no RC pelo telefone e ver o terminal responder em tempo real
- Nenhuma edição necessária além de corte: gravação contínua única
- Hospedar no YouTube + embed no README; também útil para lançamento no Product Hunt

### Enviar para homebrew-core para listagem no brew.sh
**Severidade:** Baixa
**Status:** Futuro - aguardando adoção
**Descrição:** claude-mux atualmente é distribuído via um tap pessoal (`pereljon/tap`). Para aparecer no brew.sh, precisa ser aceito no homebrew-core. A barreira de notabilidade do Homebrew tipicamente requer algumas centenas de estrelas no GitHub antes que uma submissão de utilitário shell script seja aceita; submissões com poucas estrelas são fechadas rapidamente.
**Quando pronto:**
- Garantir que a fórmula passe em `brew audit --strict --new`
- Enviar PR para `Homebrew/homebrew-core` com a fórmula
- Nota: ferramentas só para macOS enfrentam mais escrutínio dos revisores; suporte a Linux (veja abaixo) ajudaria

### Suporte a instalação via curl (macOS + Linux)
**Severidade:** Baixa
**Status:** Resolvido na v1.10.0 - instalação via curl implementada, workflow de release-assets adicionado, README atualizado

### Apenas macOS - sem suporte Linux/systemd
**Severidade:** Média
**Status:** Aberto - parcialmente tratado (detecção de caminho feita, LaunchAgent/instalador permanecem apenas macOS)
**Descrição:** Usa LaunchAgent do macOS (launchd) e ferramentas específicas do macOS. A detecção de caminho foi refatorada para usar `command -v` (não mais hardcoda `/opt/homebrew/bin`), então o script principal agora funciona em qualquer plataforma onde tmux e claude estejam no PATH. LaunchAgent e instalador permanecem específicos do macOS.
**Restante:** unit de usuário systemd, fallback XDG Autostart, dispatch `uname -s` no instalador.
**Estratégia de pacotes (v1.10+):**
- Instalação via curl: fallback universal, funciona em qualquer lugar (veja acima)
- AUR: baixo esforço, alto alcance para o público-alvo no Arch/Manjaro
- apt PPA: quando houver demanda de usuários Debian/Ubuntu
- Homebrew no Linux: cobre usuários que já o têm
- Snap/Flatpak: não vale a pena para um script bash

### Comandos ! não disponíveis no Remote Control
**Severidade:** Baixa
**Status:** Fechado - não viável
**Descrição:** O passthrough de shell `!` do Claude Code é uma funcionalidade do manipulador de entrada da CLI do Claude Code: ele intercepta `!command` antes do shell ver. tmux send-keys não pode replicar isso: keystrokes enviados enquanto o Claude Code está ativo não vão a lugar nenhum (testado: `!touch test` via send-keys não executou). Não há caminho para o claude-mux implementar bypass de `!command` para usuários RC.
**Resolução:** Adicionar regra de injeção dizendo ao Claude para nunca sugerir `! <command>` aos usuários, já que usuários RC não têm shell e usuários de terminal podem simplesmente digitá-lo.

---

## Marco v2.0

Mudanças arquiteturais significativas o suficiente para justificar um bump de versão major. Sem cronograma definido: coletadas aqui para não se perderem.

### Separação de diretório de dados
Mover dados estáticos (dicas, templates padrão, possivelmente saída de command/guide) para fora do script e para um diretório de dados apropriado à plataforma. O script resolveria `DATA_DIR` na inicialização relativo à localização do binário, com fallbacks embutidos para instalações de arquivo único.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` ou `$XDG_DATA_DIRS`
- Instalação manual: fallback para padrões embutidos (instalações de arquivo único continuam funcionando)

Gatilho: quando os dados embutidos (dicas, templates padrão) crescerem o suficiente para dificultar a leitura do script, ou quando templates padrão precisarem ser distribuídos via brew independentemente dos releases do script.

### Reconsideração de linguagem / runtime
O script bash monolítico é a decisão certa no escopo atual. Se o claude-mux crescer significativamente (operações de renomear/mover/copiar projeto, uma camada de relay, empacotamento cross-platform, um diretório de dados) o bash começa a resistir. Nesse ponto, reescrever o núcleo de gerenciamento de sessões em Go ou outra linguagem tipada (com bash como wrapper CLI fino) vale a pena avaliar.

---

## Resolvidos

### Claude ignora injeção e diz que não pode executar slash commands
**Resolvido em:** v1.2.0 (injeção atualizada)
**Correção:** Adicionada regra explícita na injeção: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." O treinamento base do Claude o inclina a acreditar que não pode controlar seu próprio modelo/configurações; a regra explícita sobrescreve isso na prática.

### Múltiplos comandos retornam exit code 1 apesar de sucesso
**Resolvido em:** v1.2.0 (restart), v1.3.0 (todos os comandos)
**Correção:** Adicionado `exit 0` explícito após cada caminho de dispatch no case statement. O último comando em uma função pode vazar um exit code não-zero de testes internos ou chamadas grep.

### --dry-run dá saída enganosa para --restart
**Resolvido em:** v1.2.0 (commit a10c0c2)
**Correção:** Dry-run agora mostra "Would restart session" em vez de simular kill e depois verificar o estado real.

### Detecção de sessão falha com pgrep no macOS
**Resolvido em:** commit e1b11b5
**Correção:** Substituído `pgrep -P` por `ps -eo` + `awk` para detecção confiável de processos filhos.

### Variável $TMUX sombreou variável de ambiente do tmux
**Resolvido em:** commit 02a2e82
**Correção:** Renomeado para `$TMUX_BIN`.

### Incompatibilidade com Bash 3.2 (declare -A)
**Resolvido em:** commit 575eac1
**Correção:** Substituídos arrays associativos por detecção de colisão baseada em string.

---

## Referência: Estrutura da pasta ~/.claude

Documentada aqui porque várias funcionalidades planejadas (renomear, mover, copiar, limpeza) precisam interagir com esta estrutura corretamente. Não exaustiva: cobre as partes relevantes para o claude-mux.

### Histórico e memória do projeto: `~/.claude/projects/`

Um subdiretório por diretório de trabalho onde o Claude Code foi usado. Nomeado pela codificação do caminho absoluto: `/` -> `-`, espaços e caracteres especiais -> `-`. Lossy mas legível.

Conteúdo de cada pasta de projeto:
- `<uuid>.jsonl`: transcrição completa da conversa daquela sessão. Um arquivo por conversa.
- `<uuid>/`: subdiretório de artefatos associados a uma conversa (tasks, plans). UUID corresponde ao arquivo `.jsonl`.
- `memory/`: arquivos de memória persistente entre sessões (markdown com frontmatter). Presente apenas se memória foi escrita para o projeto.

O link entre um diretório de trabalho e seu histórico é puramente o nome da pasta codificado. Renomear ou mover o diretório do projeto sem renomear esta pasta faz o Claude Code começar do zero sem histórico.

**Regra de codificação:** caminho absoluto com cada `/`, espaço e caractere especial substituído por `-`. O `/` inicial vira um `-` inicial. A codificação é lossy: caracteres especiais consecutivos e espaços adjacentes a barras ambos viram `-`, então o original nem sempre pode ser perfeitamente reconstruído.

### Registro de observabilidade paralela: `~/.claude/homunculus/`

Um sistema separado que rastreia eventos de ferramenta por projeto. Não faz parte do histórico central do Claude Code: parece ser uma camada de monitoramento/aprendizado.

- `projects.json`: registro de todos os projetos conhecidos, indexados por UUID hexadecimal curto (`d6b3aef60967`, etc.). Cada entrada tem: `id`, `name`, `root` (caminho absoluto), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json`: metadados por projeto (mesmos campos que a entrada no registro).
- `projects/<uuid>/observations.jsonl`: eventos `tool_start`/`tool_complete` com timestamp: nome da ferramenta, UUID da sessão, nome/id do projeto, trechos de input/output.
- `projects/<uuid>/instincts`: padrões derivados (conteúdo desconhecido, provavelmente computado).
- `projects/<uuid>/evolved`: estado evoluído/aprendido (conteúdo desconhecido).
- `projects/<uuid>/observations.archive`: observações antigas arquivadas.

**Diferença chave de `~/.claude/projects/`:** Usa UUIDs hexadecimais curtos como chaves, não caminhos codificados. O campo `root` contém o caminho absoluto. Qualquer operação que mude o caminho de um projeto (renomear, mover) precisa atualizar `root` em ambos `projects.json` e `projects/<uuid>/project.json`.

### Config global: `~/.claude/settings.json`

Arquivo principal de configurações do Claude Code. Backups rotativos são escritos em `~/.claude/backups/` como `~/.claude.json.backup.<timestamp>`: vários por hora durante uso ativo. claude-mux não deve tocar neste arquivo.

### Agents, skills, commands globais

- `~/.claude/agents/`: definições de subagentes (arquivos `.md`, ~38). Globais, não por projeto.
- `~/.claude/skills/`: diretórios de skills (~125). Globais, não por projeto.
- `~/.claude/commands/`: definições de slash commands (arquivos `.md`, ~72). Globais, não por projeto.
- `~/.claude/hooks/hooks.json`: definições de hooks. Globais. claude-mux não deve tocar nestes.

### Funcionalidades futuras potenciais

| Funcionalidade | O que tocar |
|----------------|-------------|
| `--copy` | Criar diretório; iniciar+parar sessão para inicializar ambos registros; copiar `.jsonl` + `memory/` + subdiretórios UUID; copiar arquivos de observação do homunculus para a nova pasta UUID |
| Limpeza do `--delete` | Já move a pasta do projeto para a lixeira. Opcionalmente: remover pasta `~/.claude/projects/` codificada órfã e entrada em `~/.claude/homunculus/` |
| Aviso de tamanho do histórico | Alertar quando os arquivos `.jsonl` de um projeto excederem um limite (a transcrição principal do claude-mux atingiu 107MB em uma única sessão longa) |
