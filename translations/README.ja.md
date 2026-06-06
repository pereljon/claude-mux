# claude-mux - Claude Code マルチプレクサ

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · **日本語** · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

すべてのプロジェクトに対して永続的な Claude Code セッションを提供し、Claude モバイルアプリからどこでもアクセスできます。***Managed by Claude!***

## インストール

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

セッションを開始:

```bash
claude-mux ~/path/to/your/project
```

インストーラはログイン時に home セッションを自動起動するか尋ねます。同意すると、ログインのたびに保護された Claude セッションが自動起動し、ターミナルを開かなくてもスマートフォンや任意の Remote Control クライアントからいつでもアクセスできます。

これだけです。Remote Control が有効化された永続的でセッション認識型の Claude セッションに入れます。**ここからはすべて会話で操作できます。**

[Homebrew、手動インストール、その他のオプション](../docs/INSTALL.md)

## なぜ必要か

Remote Control はどこからでも Claude Code を使えることを約束していますが、セッション管理なしでは Claude Desktop からでさえ二流のインターフェースです:

- ターミナルを閉じると**セッションが終了**する
- **会話コンテキスト**が自動的に再開されない
- **常時起動のホームベースがない** - 何かを開いたままにしていない限り、スマートフォンを手に取っても何も動いていない
- **Remote Control には起動中のセッションが必要** - RC からセッションを開始することはできない
- **RC セッションではスラッシュコマンドが動作しない** - モデル切り替え、コンパクト化、permission モード変更が不可
- **新しいプロジェクトの開始** - ディレクトリの手動作成、git の初期化、CLAUDE.md の作成、モデルの選択が必要
- **プロジェクト管理がない** - アイドル状態のプロジェクトの確認や、履歴を壊さずにプロジェクトの名前変更、移動、削除ができない

**claude-mux はセッション管理のギャップを解決します。** Claude Code を tmux でラップしてセッションを永続化し、Claude が自身のセッションを管理できるようシステムプロンプトを注入し、スラッシュコマンドを tmux 経由でルーティングして Remote Control 上でも動作するようにします。セッションが起動したら、ターミナルからでもモバイルアプリからでも、Claude に話しかけることですべてを管理できます。

## claude-mux セッションでできること

- **任意のセッションから任意のセッションを管理** - 自然言語でプロジェクトの起動、停止、再起動、一覧表示、コンパクト化
- **どこからでもアクセス** - 全セッションで Remote Control が有効なので、Claude モバイルアプリ、デスクトップアプリ、その他のリモートクライアントがフルインターフェースになる
- **モデルと permission モードの切り替え** - 「Haiku に切り替えて」や「plan モードに切り替えて」と言えば、Remote Control 経由でも Claude が処理
- **新規プロジェクトの作成** - 「my-app という新規プロジェクトを作成して」で、ディレクトリ作成、git 初期化、CLAUDE.md 設定、セッション起動まで完了。CLAUDE.md テンプレートでプロジェクト間で指示を再利用可能
- **再起動後もセッションを維持** - オプションの home セッションがログイン時に起動して常時動作。全セッションが自動的に直前の会話を再開
- **Remote Control 経由でスラッシュコマンドを送信** - `/model`、`/compact`、`/clear` などのスラッシュコマンドを Claude が実行中のセッションにルーティングし、[既知の制限](https://github.com/anthropics/claude-code/issues/30674)を回避
- **会話履歴の保持** - プロジェクトの名前変更、移動、再起動でも会話履歴を自動的に保持
- **プロジェクトの整理** - 任意のセッション内からプロジェクトの非表示、名前変更、移動、削除、保護
- **GitHub マルチアカウント対応** - `~/.ssh/config` の SSH エイリアスを検出してセッションに注入し、プロジェクトごとに正しいアカウントを使用
- **マルチ CLI ツール対応** - `AGENTS.md` や `GEMINI.md` のシンボリックリンクを自動作成し、Codex CLI、Gemini CLI などのツールが指示を共有
- **どの言語でも動作** - 会話コマンドはキーワードではなく意図から推測される

## Claude に話しかける

これが claude-mux の日常的な使い方です。各セッションにはコマンドが注入されており、Claude はセッション管理、モデル切り替え、スラッシュコマンド送信、新規プロジェクト作成をすべて会話の中から実行できます。CLI フラグを覚える必要はありません。

```
あなた：「status」
Claude：セッション名、モデル、permission モード、コンテキスト使用量を報告し、全セッションを一覧表示

あなた：「アクティブなセッションを一覧表示して」
Claude：動作中の全セッションをステータス付きで表示

あなた：「api-server プロジェクトのセッションを開始して」
Claude：~/Claude/work/api-server にセッションを起動

あなた：「web テンプレートを使って mobile-app という新規プロジェクトを作成して」
Claude：プロジェクトディレクトリを作成し、git を初期化して、テンプレートを適用し、セッションを起動

あなた：「このセッションを Haiku に切り替えて」
Claude：tmux 経由で自身に /model haiku を送信

あなた：「api-server セッションをコンパクト化して」
Claude：api-server セッションに /compact を送信

あなた：「web-dashboard セッションを再起動して」
Claude：セッションをシャットダウンして再起動し、会話コンテキストを保持

あなた：「api-server セッションを plan モードに切り替えて」
Claude：plan permission モードでセッションを再起動

あなた：「このセッションを yolo モードに切り替えて」
Claude：Shift+Tab 経由で bypassPermissions モードに切り替え - 再起動不要

あなた：「このセッションのモードは？」
Claude：現在の permission モード (default、acceptEdits、plan、bypassPermissions) を報告

あなた：「このセッションを Opus に切り替えて」
Claude：tmux 経由で自身に /model opus を送信

あなた：「このセッションをクリアして」
Claude：自身に /clear を送信して会話をリセット

あなた：「このプロジェクトを非表示にして」
Claude：.claudemux-ignore を書き込み、-L 一覧から除外

あなた：「このセッションを保護して」
Claude：.claudemux-protected を書き込み、tmux マーカーを設定 - シャットダウンには --force が必要に

あなた：「このセッションは保護されてる？」
Claude：プロジェクトフォルダの .claudemux-protected を確認して報告

あなた：「old-prototype プロジェクトを削除して」
Claude：チャットで確認後、プロジェクトフォルダをシステムのゴミ箱に移動

あなた：「このプロジェクトを my-new-name にリネームして」
Claude：セッションを停止し、フォルダ名を変更し、会話履歴を移行して再起動

あなた：「これを web という名前のテンプレートとして保存して」
Claude：CLAUDE.md を ~/.claude-mux/templates/web.md にコピー

あなた：「tip」
Claude：ヒントを表示 - 同じ日は同じヒント、TIP_MODE=random を設定するとランダム

あなた：「ヒントを有効にして」/「ヒントを無効にして」
Claude：全プロジェクトで毎日のヒントをオン/オフ

あなた：「update claude-mux」
Claude：全セッションが再起動される旨を警告し、確認後にアップデートと再起動を実行

あなた：「全セッションを停止して」
Claude：管理対象の全セッションを正常終了

あなた：「help」
Claude：会話コマンドの全一覧を表示
```

**これらのコマンドはどの言語でも動作します。** スペイン語、日本語、ヘブライ語など、他の言語で同等の表現を入力しても、Claude は意図を読み取って対応するコマンドを実行します。

**任意のセッション内で `help` と入力すると、コマンド一覧を確認できます。**

## その他

- [CLI リファレンス](../docs/CLI.md) - スクリプトと自動化のためのコマンド全体リファレンス
- [ガイド](../docs/guide.md) - 設定、セッション詳細、内部構造、トラブルシューティング
- [インストールオプション](../docs/INSTALL.md) - Homebrew、手動インストール、LaunchAgent のセットアップ
- [FAQ](../docs/FAQ.md) - claude-mux に関するよくある質問
- [既知の問題](../docs/ISSUES.md) - 未解決のバグ、計画中の機能、解決済みの問題
- [変更履歴](../CHANGELOG.md) - リリースごとの変更内容
