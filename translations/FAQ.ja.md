# よくある質問

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · **日本語** · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## claude-mux とは？

Claude Code を tmux でラップして永続セッションを提供するシェルスクリプトです。ターミナルを閉じてもセッションは維持され、再起動時に会話コンテキストが再開され、Remote Control 経由で Claude モバイルアプリからアクセスできます。セッション内で Claude に話しかけることですべてを管理します。

## Linux で動作しますか？

まだ対応していません。macOS のみ (Apple Silicon および Intel) です。Linux 対応は v2.0 で計画されています。インストーラは Linux 上でも動作しますが、LaunchAgent のセットアップはスキップされ、メッセージが表示されます。バイナリ自体は動きますが、systemd サービスや同等の自動起動メカニズムはまだありません。

## home セッションとは？

home セッションはベースディレクトリ (デフォルトは `~/Claude`) に置かれた汎用 Claude セッションです。`LAUNCHAGENT_MODE=home` (デフォルト) の場合、ログイン時に自動起動して終日動作します。デフォルトで**保護**されており、`--shutdown home` は `--force` なしでは停止を拒否します。

home セッションは Claude モバイルアプリからの常時利用可能なエントリポイントとして使えます。ここからプロジェクトの一覧表示、他のセッションの起動、設定の管理、特定のプロジェクトに属さない一般的な作業を行えます。

## Remote Control とは？

Remote Control (RC) は Claude Code の機能で、Claude モバイルアプリまたは Claude Desktop から動作中の Claude セッションに接続できるようにするものです。claude-mux はすべてのセッションを `--remote-control` 有効で起動するため、全セッションが RC のリストに自動的に表示されます。接続後は、ターミナルと同じように Claude に話しかけることができます。claude-mux はスラッシュコマンドがネイティブに動作しないなどの RC の制限も tmux 経由のルーティングで回避します。

## permission モードとは？

Claude Code には、Claude の自律性を制御する 4 つの permission モードがあります:

| モード | 動作 |
|--------|------|
| `default` | コマンド実行やファイル編集の前に Claude が確認を求める |
| `acceptEdits` | ファイル編集は自動適用するが、シェルコマンドの前に確認を求める |
| `plan` | 読み取りと計画のみ。書き込みやコマンド実行は不可 |
| `bypassPermissions` | Claude は確認なしですべてを実行 (初回起動時に確認が必要) |

全プロジェクトのデフォルトは config の `DEFAULT_PERMISSION_MODE` で設定します。動作中のセッションを切り替えるには「このセッションを plan モードに切り替えて」(または任意のモード名) と言います。「yolo」は `bypassPermissions` のエイリアスです。

他のモードから `bypassPermissions` への切り替えは Shift+Tab ナビゲーションを使用し、再起動は不要です。`bypassPermissions` から他のモードへの切り替えは再起動が必要ですが、claude-mux が自動的に処理します。

## セッションをリセットするには？

目的に応じて 3 つの方法があります:

- **クリア** (「このセッションをクリアして」): セッションに `/clear` を送信。会話履歴を消去して最初からやり直す。セッションは動作し続ける。
- **コンパクト** (「このセッションをコンパクト化して」): セッションに `/compact` を送信。会話を短い要約に圧縮し、コンテキストウィンドウを解放する。履歴は圧縮された形で保持。
- **再起動** (「このセッションを再起動して」): Claude をシャットダウンして `claude -c` で再起動。直前の会話を再開する。クリーンなプロセスが必要なとき (permission モード変更後や Claude がスタックしたとき等) に使用。

## テンプレートとは？

テンプレートは `~/.claude-mux/templates/` に保存される再利用可能な CLAUDE.md ファイルです。`-n` で新規プロジェクトを作成する際、デフォルトテンプレート (または `--template NAME` で指定したもの) がプロジェクトの CLAUDE.md としてコピーされます。

テンプレートの作成: 「これを web という名前のテンプレートとして保存して」(現在のプロジェクトの CLAUDE.md を `~/.claude-mux/templates/web.md` にコピー)。

テンプレートの使用: `claude-mux -n ~/projects/my-app --template web` またはセッション内から: 「web テンプレートを使って my-app という新規プロジェクトを作成して」。

テンプレートの一覧: 「list templates」または `claude-mux --list-templates`。

## 今日のヒント (tip-of-the-day) はどう動作する？

各プロジェクトの `.claude/settings.local.json` にある Claude Code の `UserPromptSubmit` hook が、プロンプトごとに `claude-mux --on-prompt` を呼び出します。その日の最初のプロンプトで会話にヒントを1つ注入し、同じ日のそれ以降のプロンプトでは何も注入しません。状態はセッションごとで `~/.claude-mux/tip-state/<session_id>.json` に保存されるため、各アクティブセッションは1日1回ヒントを表示します。この hook はコンテキストに注入するため (出力がトランスクリプトのみの Stop hook とは異なり)、ヒントは会話と Remote Control で見えます。

ヒントはデフォルトで有効です (`TIP_OF_DAY=true`)。任意のセッション内で「enable tips」または「disable tips」で切り替えられます。`TIP_MODE=daily` は一日中同じヒントを表示し、`TIP_MODE=random` はランダムなヒントを選びます。

`--tip` コマンドは日次ゲートに関係なく (また `TIP_OF_DAY` に関係なく) 常に動作するため、いつでも「tip」と言えます。

## 複数の GitHub アカウントで使えますか？

使えます。claude-mux は `~/.ssh/config` 内の `Host github.com-*` エントリを検出し、各セッションのシステムプロンプトに注入します。Claude はどの SSH エイリアスが利用可能かを把握し、git リモートの設定時に正しいものを使用できます。

`~/.ssh/config` の設定例:

```
Host github.com-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_work

Host github.com-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_personal
```

Claude は仕事用リポジトリには `git@github.com-work:org/repo.git` を、個人用リポジトリには `git@github.com-personal:user/repo.git` を使うことを理解します。

## 状態はどこに保存されますか？

| 場所 | 内容 |
|------|------|
| `~/.claude-mux/config` | ユーザー設定 (bash としてソース) |
| `~/.claude-mux/templates/` | CLAUDE.md テンプレートファイル |
| `~/.claude-mux/tip-state/<session_id>.json` | セッションごとのヒント日付 + 更新通知のスロットル |
| `~/.claude-mux/.update-check` | キャッシュされたバージョンチェック結果 |
| `~/.claude-mux/.update-checking` | バックグラウンド更新チェック中のロック |
| `~/Library/Logs/claude-mux.log` | ログファイル (`LOG_DIR` で設定可能) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist (`--install` で生成) |
| `.claudemux-protected` (プロジェクトごと) | セッションをシャットダウンから保護するマーカー |
| `.claudemux-ignore` (プロジェクトごと) | プロジェクトを一覧から非表示にするマーカー |

マーカーファイル (`.claudemux-*`) は各プロジェクトのルートディレクトリに置かれ、名前変更、移動、同期に追従します。自動的に `.gitignore` に追加されます。

会話履歴は Claude Code 自体が管理し、`~/.claude/projects/` に保存されます。

## claude-mux をフォークした場合、自動アップデートはどうなりますか？

アップデートチェックと `--update` コマンドは GitHub リポジトリとして `pereljon/claude-mux` をハードコードしています。フォークした場合でも、アップデートチェックは上流のリリースと比較し、`--update` はフォークのバイナリを上流のもので上書きします。無効にするには `~/.claude-mux/config` で `UPDATE_CHECK=false` を設定するか、スクリプト内の `check_for_update()` と `do_update()` 関数でリポジトリ URL を変更してください。

## Homebrew でインストールするには？

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

`brew upgrade claude-mux` で更新できます。Homebrew 経由でインストールした場合、`--update` は自動的に `brew upgrade` に委譲します。

## `claude --worktree --tmux` との違いは？

`claude --worktree --tmux` は隔離された git worktree 用に tmux セッションを作成するもので、並列コーディングタスク向けに設計されています。claude-mux は実際のプロジェクトディレクトリの永続セッションを管理し、Remote Control の有効化、セルフ管理のためのシステムプロンプト注入、会話再開、セッションライフサイクル管理を提供します。解決する問題が異なります。

## Claude Cowork Dispatch との違いは？

Dispatch は Claude デスクトップアプリからタスクを起動しますが、アプリが動作中である必要があり、特定のプロジェクトにバインドされません。claude-mux は永続的でプロジェクトに紐付いたセッションを管理し、再起動後も維持され、Remote Control 経由でどこからでもアクセスでき、デスクトップアプリは不要です。

## セッションに「Not logged in」と表示されるのはなぜ？

初回起動時に macOS のキーチェーンがロックされている場合に発生します。ログイン後にキーチェーンがアンロックされる前に LaunchAgent が起動するケースで一般的です。通常のターミナルで `security unlock-keychain` を実行し、任意のセッションにアタッチ (`claude-mux -t <name>`) して `/login` でブラウザ認証フローを完了してください。その後、全セッションを再起動すれば、保存された認証情報を自動的に拾います。

## 複数のターミナルから同じセッションにアタッチできますか？

できます。これは標準的な tmux の動作です。すでに動作中のセッションがあるディレクトリで `claude-mux` を実行すると、そのセッションにアタッチします。複数のターミナルからリアルタイムで同じセッションの内容を確認できます。

## home セッションを永続的に停止するには？

LaunchAgent は `KeepAlive: true` に設定されているため、home セッションを kill すると約 60 秒以内に再起動します。永続的に停止するには LaunchAgent を無効化してください:

```bash
claude-mux --install --launchagent-mode none
```

## 「Session ready!」メッセージの意味は？

セッションの起動または再起動時、Claude の読み込み完了後に claude-mux が `Ready?` プロンプトを送信します。注入された指示により、Claude は「Session ready!」とだけ返答します。これでセッションが生きており、システムプロンプトの注入が機能していることを確認できます。無視して構いません。

## プロジェクトを一覧から非表示にするには？

任意のセッション内で「このプロジェクトを非表示にして」と言うか、`claude-mux --hide my-project` を実行します。`.claudemux-ignore` マーカーファイルが作成されます。そのプロジェクトは `claude-mux -L` の出力に表示されなくなります。非表示のプロジェクトを確認するには: `claude-mux -L --hidden`。非表示を解除するには: 「このプロジェクトを表示して」または `claude-mux --show my-project`。

## claude-mux をアンインストールするには？

```bash
claude-mux --uninstall
```

全プロジェクトからヒントの hook と permission ルールを削除し、LaunchAgent をアンロードし、オプションで `~/.claude-mux/` を削除します。バイナリのパスが報告されるため、手動で削除できます (Homebrew 経由でインストールした場合は `brew uninstall claude-mux`)。

## スラッシュコマンドは Remote Control で動作しますか？

ネイティブには動作しません。Claude Code は RC セッションでスラッシュコマンド (`/model`、`/clear` 等) をサポートしていません。claude-mux は各セッションに `claude-mux -s` を注入して回避しています。Claude が tmux 経由で自身にスラッシュコマンドを送信できます。「Haiku に切り替えて」や「このセッションをコンパクト化して」と言うだけで Claude が処理します。

## セッション内でテキストを選択できない

**Option** キー (macOS) または **Shift** キー (Linux/Windows ターミナル) を押しながらクリック&ドラッグしてください。tmux のマウスキャプチャをバイパスし、選択範囲がシステムクリップボードにコピーされます。設定変更は不要です。

## 会話コマンドはどの言語に対応していますか？

すべての言語に対応しています。トリガーフレーズ (「help」、「status」、「list sessions」等) はどの言語でも動作します。Claude はユーザーの自然言語から意図を推測し、対応するコマンドを実行します。README も 12 言語に翻訳されています。
