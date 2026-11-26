# claude-mux - Multiplexador do Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sessoes persistentes do Claude Code para todos os seus projetos - acessiveis de qualquer lugar pelo app movel do Claude. ***Gerenciado pelo Claude!***

## Instalar

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Depois inicie uma sessao:

```bash
claude-mux ~/caminho/para/seu/projeto
```

O instalador pergunta se voce quer uma sessao home no login. Se aceitar, uma sessao protegida do Claude inicia automaticamente toda vez que voce faz login - sempre acessivel pelo celular ou qualquer cliente Remote Control, mesmo que voce nunca abra o terminal.

E isso! Voce esta em uma sessao persistente e contextualizada do Claude com Remote Control habilitado. **A partir daqui, tudo e por conversa.**

[Homebrew, instalacao manual e outras opcoes](../docs/INSTALL.md)

## Por que

Remote Control promete Claude Code de qualquer lugar - mas sem gerenciamento de sessoes, e uma interface de segunda classe mesmo pelo Claude Desktop:

- **Sessoes morrem** quando voce fecha o terminal - e nao voltam depois de uma falha ou reinicializacao
- **Contexto da conversa** nao retoma automaticamente
- **Sem base fixa** - nada esta rodando quando voce pega o celular, a menos que tenha deixado algo aberto
- **Remote Control precisa de uma sessao rodando** - voce nao pode iniciar uma pelo RC
- **Slash commands nao funcionam em sessoes RC** - sem troca de modelo, compactacao ou mudanca de modo de permissao
- **Iniciar novos projetos** - exige criar manualmente um diretorio, inicializar git, escrever um arquivo de instrucoes (AGENTS.md ou CLAUDE.md) e escolher um modelo
- **Sem gerenciamento de projetos** - sem como ver projetos inativos, ou renomear, mover e excluir projetos sem perder o historico

**claude-mux resolve a lacuna no gerenciamento de sessoes.** Ele envolve o Claude Code em tmux para que sessoes persistam, restaura-as automaticamente apos falhas e reinicializacoes (desde que o login automatico esteja habilitado), injeta um system prompt para que o Claude gerencie suas proprias sessoes, e roteia slash commands pelo tmux para que funcionem via Remote Control. Uma vez que a sessao esta rodando, voce gerencia tudo conversando com o Claude - no terminal ou no app movel.

## O que voce pode fazer em uma sessao claude-mux

- **Sobrevive a falhas e reinicializacoes** - as sessoes sao restauradas automaticamente quando voce faz login de novo, retomando a ultima conversa. Um `/exit` normal ou um desligamento mantem a sessao parada; uma sessao em loop de falhas e interrompida e sinalizada, em vez de ser reiniciada para sempre.
- **Gerenciar qualquer sessao de qualquer sessao** - iniciar, parar, reiniciar, listar e compactar projetos usando linguagem natural
- **Acessar tudo de qualquer lugar** - toda sessao tem Remote Control habilitado, entao o app movel do Claude, app desktop ou qualquer cliente remoto e uma interface completa
- **Trocar modelos e modos de permissao** - diga "mude para Haiku" ou "mude para modo plan" e o Claude faz isso, mesmo pelo Remote Control
- **Criar novos projetos** - "crie um novo projeto chamado my-app" configura diretorio, git, um AGENTS.md a partir de um template e inicia uma sessao. Templates permitem reutilizar instrucoes entre projetos.
- **Enviar slash commands pelo Remote Control** - o Claude roteia `/model`, `/compact`, `/clear` e outros slash commands para a sessao rodando, contornando uma [limitacao conhecida](https://github.com/anthropics/claude-code/issues/30674). O RC reconecta automaticamente apos `/compact` por meio de um hook `PreCompact`.
- **Deteccao de atualizacao do Claude Code** - quando o binario `claude` muda (apos `brew upgrade` ou uma atualizacao npm), as sessoes em execucao exibem um aviso para reiniciar e carregar o novo binario; o aviso persiste entre os prompts ate voce reiniciar, entao um turno perdido nao o faz sumir
- **Preservar historico de conversas** - renomear, mover e reiniciar projetos preservam o historico de conversas automaticamente
- **Organizar projetos** - ocultar, renomear, mover, excluir e proteger projetos de dentro de qualquer sessao
- **Suporte a multiplas contas GitHub** - detecta aliases SSH em `~/.ssh/config` e os injeta nas sessoes para que o Claude use a conta certa por projeto
- **AGENTS.md como arquivo de instrucoes do projeto** - `AGENTS.md` e o unico arquivo real, lido pelo Claude Code e pelo Codex CLI. Diga "migrate to AGENTS.md" para converter uma arvore existente a partir de `CLAUDE.md` (primeiro um relatorio, nada e commitado). Requer Claude Code 2.1.277 ou posterior; versoes mais antigas mantem `CLAUDE.md`. O Gemini CLI so le o arquivo se `~/.gemini/settings.json` tiver `"context": {"fileName": ["AGENTS.md"]}`.
- **Funciona em qualquer idioma** - comandos conversacionais sao inferidos pela intencao, nao por palavras-chave

## Conversando com o Claude

E assim que voce usa o claude-mux no dia a dia. Cada sessao recebe comandos injetados para que o Claude gerencie sessoes, troque modelos, envie slash commands e crie novos projetos - tudo de dentro da conversa. Voce nao precisa lembrar flags do CLI.

```
Diga: "status"
Reporta nome da sessao, modelo, modo de permissao, uso de contexto e lista todas as sessoes

Diga: "listar sessoes ativas"
Mostra todas as sessoes rodando com seu status

Diga: "listar sessoes inativas"
Mostra apenas os projetos inativos

Diga: "listar sessoes paradas"
Mostra apenas as sessoes paradas

Diga: "inicie uma sessao para meu projeto api-server"
Inicia a sessao pelo nome; nao faz nada se ela ja estiver rodando

Diga: "crie um novo projeto chamado mobile-app usando o template web"
Cria o diretorio do projeto, inicializa git, aplica o template, inicia uma sessao

Diga: "mude esta sessao para Haiku"
Resolve a familia para o ID concreto mais recente e envia /model claude-haiku-4-5 para si mesmo

Diga: "compacte a sessao api-server"
Envia /compact para a sessao api-server

Diga: "reinicie a sessao web-dashboard"
Encerra e reinicia a sessao, preservando o contexto da conversa

Diga: "reinicie esta sessao do zero"
Pede confirmacao, depois reinicia com uma nova conversa - sem retomar, sem contexto anterior

Diga: "mate a sessao api-server"
Pede confirmacao, depois limpa a conversa e a para; o proximo inicio e uma nova conversa, nao uma retomada

Diga: "finalize esta sessao"
Salva primeiro o trabalho inacabado e o proximo passo, pede confirmacao (e se ha algo nao salvo), depois reinicia do zero

Diga: "mude a sessao api-server para modo plan"
Reinicia a sessao com modo de permissao plan

Diga: "mude esta sessao para modo yolo"
Muda para o modo bypassPermissions via Shift+Tab - sem necessidade de reinicio

Diga: "qual o modo desta sessao"
Reporta o modo de permissao atual (default, acceptEdits, plan, bypassPermissions)

Diga: "mude esta sessao para Opus"
Resolve a familia para o ID concreto mais recente e envia /model claude-opus-4-8 para si mesmo

Diga: "limpe esta sessao"
Pede confirmacao, depois envia /clear para si mesmo, resetando a conversa

Diga: "oculte este projeto"
Escreve .claudemux-ignore para que o projeto seja excluido das listagens -L

Diga: "proteja esta sessao"
Escreve .claudemux-protected e define o marcador tmux - o desligamento agora exige --force

Diga: "esta sessao esta protegida"
Verifica se .claudemux-protected existe na pasta do projeto e reporta

Diga: "exclua o projeto old-prototype"
Confirma no chat, depois move a pasta do projeto para a lixeira do sistema

Diga: "renomeie este projeto para my-new-name"
Para a sessao, renomeia a pasta, migra o historico de conversas, reinicia

Diga: "salve isso como template com nome web"
Copia AGENTS.md (ou CLAUDE.md) para ~/.claude-mux/templates/web.md

Diga: "verificar migracao para agents" / "migrar para AGENTS.md"
Reporta (somente leitura) quais arquivos CLAUDE.md podem virar AGENTS.md; apos confirmacao, os renomeia em toda a arvore e reinicia as sessoes em execucao sob o diretorio base

Diga: "tip"
Mostra uma dica - a mesma o dia todo, ou aleatoria se TIP_MODE=random estiver definido

Diga: "ativar tips" / "desativar tips"
Ativa ou desativa a dica do dia em todos os projetos

Diga: "atualizar claude-mux"
Avisa que todas as sessoes serao reiniciadas, pede confirmacao, atualiza e reinicia

Diga: "parar todas as sessoes"
Encerra ordenadamente todas as sessoes gerenciadas

Diga: "help"
Mostra a lista completa de comandos conversacionais
```

**Esses comandos funcionam em qualquer idioma.** Se voce digitar o equivalente em portugues, japones, hebraico ou qualquer outro idioma, o Claude infere a intencao e executa o comando correspondente.

**Digite `help` dentro de qualquer sessao para ver a lista completa de comandos.**

## Mais

- [Referencia CLI](../docs/CLI.md) - referencia completa de comandos para scripting e automacao
- [Guia](../docs/GUIDE.md) - configuracao, detalhes de sessao, internos e solucao de problemas
- [Opcoes de instalacao](../docs/INSTALL.md) - Homebrew, instalacao manual, configuracao do LaunchAgent
- [FAQ](../docs/FAQ.md) - perguntas frequentes sobre claude-mux
- [Problemas conhecidos](../docs/ISSUES.md) - bugs abertos, features planejadas e problemas resolvidos
- [Changelog](../CHANGELOG.md) - mudancas por release
