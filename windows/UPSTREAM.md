# Windows IME の由来

Windows TSF クライアント、Swift 変換サーバー、候補ウィンドウ、設定画面は
[fkunn1326/azooKey-Windows](https://github.com/fkunn1326/azooKey-Windows)
のコミット `65835aa1afd9ae7fafd7c58a86ea017877ebc58f` を基にしています。
元の MIT ライセンスは `LICENSE` に保持しています。

このディレクトリのソースは本リポジトリで管理します。ビルド時に最新版の
Windows クライアントを取得する仕組みではありません。
辞書と Swift パッケージのリビジョンは固定しています。

Windows は x64 OS 用です。TSF DLL は x64 と x86 の両方を同梱します。
macOS の Core / AppKit の直接移植ではなく、Windows 用の変換エンジンと
TSF 実装を使用します。macOS 版の設定・学習・Zenzai の版とは独立しています。
