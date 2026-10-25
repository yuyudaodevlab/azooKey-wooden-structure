# Windows IME とインストーラーの自動ビルド

## Windows

`windows/` は Windows TSF の IME です。x64 Windows 用に、64 bit アプリ向けと
32 bit アプリ向けの TSF DLL、Swift のかな漢字変換サーバー、候補ツリー、設定画面を
同梱します。上流実装とライセンスについては `windows/UPSTREAM.md` を参照してください。

インストーラーを管理者権限で実行し、Windows を再起動します。
「設定 → 時刻と言語 → 言語と地域 → 日本語 → 言語のオプション」のキーボードで
`AzooKeyWooden` を選択・追加してください。Win + Space で入力方式を切り替えます。
設定画面はスタートメニューの「azooKey wooden structure → 設定」です。
アンインストールは Windows の「インストールされているアプリ」から行います。

候補ツリーはエンジンの読み範囲が一致する語だけを分岐として表示します。
↑↓ / Space で候補を選択し Enter で確定します。読みと表示が一致しない予測候補は
候補一覧だけに表示し、語分割を推測しません。

現時点では macOS 版との完全な機能一致ではありません。Windows は上流互換の
Swift 6.0.2 / Zenzai v3 エンジンを使います。macOS の Zenzai v3.1、辞書スコアの
比率・品詞表示、学習設定、個人最適化、候補クリックによる選択は移植していません。
通常権限のアプリ向けです。管理者権限のアプリの候補表示、ARM64 ネイティブ実行、
複数ユーザーの同時ログインは未検証です。インストーラーは開発用の未署名版です。

ローカルビルドには Visual Studio 2022 C++ Build Tools / Windows SDK、Swift 6.0.2、
Rust、Node.js 22、protoc 29.3、Inno Setup 6 が必要です。Swift の SDKROOT を設定した
PowerShell 7 で、リポジトリのルートから実行します。

```powershell
./scripts/build-windows.ps1 -Commit (git rev-parse HEAD)
```

macOS は Xcode 26.1 以降と Python 3 が必要です。

```sh
bash scripts/build-macos.sh "$(git rev-parse HEAD)"
```

macOS パッケージにはローカル実行用の ad-hoc 署名を付けますが、Developer ID 署名と
Apple 公証は行いません。一般配布用の署名には別途 Apple の証明書が必要です。

## 自動ビルドの流れ

1. `main` への push、または `main` での手動実行で開始。
2. ビルド元の **40 桁のコミットID** から `build/{コミットID}` ブランチを先に作成。
3. 同じソースコミットから macOS / Windows をそれぞれビルド。
4. 両方成功した場合だけ、次のファイルをビルドブランチにコミット。
   - `installer/azooKey-wooden-structure-{コミットID}.pkg`
   - `installer/azooKey-wooden-structure-{コミットID}.exe`
   - `installer/{コミットID}.json`（ビルドURL・サイズ・SHA-256）
5. `main` 向けPRを作成し、`yuyudaodevlab` にレビュー依頼・assign。
   PR本文とコメントでビルド結果を通知。
6. **最新の成果物コミットを `yuyudaodevlab` が承認**すると auto-merge を有効化。
   ブランチ保護で必要とされるチェック・レビュー条件が満たされると squash merge。
   Actions 自身は承認レビューを送信しません。

成果物だけのマージでは次のビルドを起動しません。失敗時は不完全なPRを作成しません。
PR公開段階だけ失敗した場合は Actions の失敗ジョブを再実行できます。
同じコミットの成果物を再ビルドしても既存の成果物コミットは上書きしません。

## GitHub 側の初回設定

以下はワークフローファイルだけでは変更されないリポジトリ設定です。

- Settings → Actions → General → Workflow permissions で PR 作成を許可。
  設定名は **Allow GitHub Actions to create and approve pull requests** ですが、
  この実装が使うのは作成のみです。承認は人間が行います。
- Settings → General → Pull Requests で **Allow auto-merge** と squash merge を許可。
- `main` のブランチ保護・ruleset で PR を必須にし、承認1件以上、
  **Require review from Code Owners** と **Dismiss stale pull request approvals when new commits are pushed**
  を有効化。`installer/` の CODEOWNER は `yuyudaodevlab`。
  承認後にブランチが更新された場合も、人間の再承認を必須にします。

`GITHUB_TOKEN` で作成したPRでは `pull_request` の検証ワークフローが自動起動しません。
そのため `Validate / validate` を必須ステータスにする場合は、PR作成を専用の
GitHub Appトークンへ切り替えてイベントを発生させる追加設定が必要です。
この構成では成果物のPR作成前に両OSのビルド成功を要求しています。
存在しないチェックを必須にすると、承認後もマージ待ちになります。

## 成果物の取得・検証

インストーラーは `installer/` に通常の Git ファイルとして保存します。
リポジトリの clone / pull、または Actions の `installer-macos` / `installer-windows` artifact から取得できます。

[GitHub の通常の Git ファイル上限は100 MiBです](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。
どちらかのインストーラーが上限を超えた場合、公開ジョブはコミット・PR作成をスキップして notice を出します。
ビルド済みファイルは Actions artifacts に14日間残ります。モデルやGPUライブラリの同梱により
上限を超える可能性があるため、その場合はパッケージの縮小または GitHub Releases での配布が必要です。

マニフェストに記載されたSHA-256と、取得したファイルのSHA-256を比較できます。
各コミットのインストーラーは履歴に残るため、リポジトリ容量はビルド回数に応じて増加します。

## 検証

### Windows の Swift 出力マップエラー

`supplementary output file map ... is missing an entry` は、Swift driver の
[Windowsでの同種の不具合報告](https://github.com/swiftlang/swift-driver/issues/1477)があります。
長いコンパイラー引数が response file に渡されるケースで報告されています。
`build-windows.ps1` では `-Xswiftc -driver-filelist-threshold -Xswiftc 0` を指定し、
ソース・出力ファイル名を専用の一覧ファイルで渡して引数の長さを減らします。
Release設定とモジュール全体の最適化は維持します。この回避策の成否はWindows CIで確認が必要です。

### テスト手順

```sh
cd windows/frontend
npm ci --ignore-scripts
npm run build
cd ../..
node --test scripts/tests/*.test.cjs
```

さらに実機またはVMで、メモ帳・ブラウザー・32 bitアプリに対する日本語入力、
候補選択、削除、未確定文字のキャンセル、再起動後の起動、アンインストールを確認してください。
