# azooKey-wooden-structure
azooKey-Desktopを木構造の変換候補にしたもの

macOS 版に加え、`windows/` に Windows TSF IME を収録しています。
Windows のビルド・インストール、両OSのインストーラーを作成する GitHub Actions、
人間の承認後の自動マージの設定は[Windows / 自動ビルド手順](docs/build-and-windows.md)を参照してください。

ビルド前に、リポジトリのルートでモデルファイルを取得してください。

```sh
python3 scripts/download-models.py
```

必要な5ファイルを取得し、サイズとSHA-256を検証します。検証済みのファイルは再ダウンロードしません。詳しいビルド手順は[開発ガイド](README%202.md)を参照してください。


## 使用しているオープンソースソフトウェア (OSS)

本プロジェクトでは、以下のオープンソースソフトウェアを使用しています。

### [azooKey](https://github.com/azooKey/azooKey)
- ライセンス: MIT License
- 著作権表示: Copyright (c) 2020-2025 Keita Miwa (ensan).

---
MIT License
