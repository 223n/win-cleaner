# Windows Cleaner

Windows環境の不要ファイルやレジストリエントリーを検出・削除する
PowerShell製CLIツール。

## 特徴

- **軽量**: PowerShell 5.1のみで動作し、追加インストール不要
- **安全**: 削除前に分析結果を表示し、ユーザー確認を必須とする
- **拡張可能**: SOLID原則に基づくモジュール設計
- **ドライラン**: 削除せずに対象を確認できる
- **ログ出力**: 実行結果を自動でファイルに記録

## 動作環境

| 項目       | 要件                                                    |
| ---------- | ------------------------------------------------------- |
| OS         | Windows 10 / 11                                         |
| PowerShell | 5.1以上                                                 |
| 権限       | 一時ファイル削除：一般ユーザー / レジストリ操作：管理者 |

## インストール

### 1. リポジトリの取得

```powershell
git clone https://github.com/223n/win-cleaner.git
cd win-cleaner
```

または、GitHubからZIPをダウンロードして展開してください。

### 2. 実行ポリシーの確認

PowerShellスクリプトを実行するには、実行ポリシーの設定が必要です。

```powershell
# 現在の設定を確認
Get-ExecutionPolicy

# RemoteSignedに変更（管理者権限のPowerShellで実行）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. 初回実行

```powershell
# 一時ファイルの削除のみ（一般ユーザーで実行可能）
.\win-cleaner.ps1

# レジストリクリーナーを使う場合は管理者権限で実行
# PowerShellを「管理者として実行」してから
.\win-cleaner.ps1
```

## 使い方

```powershell
# 通常実行
.\win-cleaner.ps1

# ドライラン（削除せずに対象を確認）
.\win-cleaner.ps1 -DryRun
```

起動するとメニューが表示されます。

```text
========================================
  Windows Cleaner v0.1.0
========================================

Log: C:\...\logs\win-cleaner_20260228_120000.log

Available modules:

  1. Temp Cleaner
     Delete temporary files and caches
  2. Registry Cleaner [Admin]
     Detect and remove invalid registry entries

  0. Exit

Select module:
```

モジュールを選択すると、分析結果が表示され`y/N`の確認後に
クリーニングが実行されます。
ドライランモードでは分析結果の表示のみ行い、削除は実行しません。

## モジュール一覧

### Temp Cleaner

一時ファイルやキャッシュを検出・削除します。管理者権限は不要です。

デフォルトの対象:

- `%TEMP%`（ユーザーTempフォルダー）
- `%SystemRoot%\Temp`（システムTempフォルダー）
- `%SystemRoot%\Prefetch`（プリフェッチファイル）
- `%SystemRoot%\SoftwareDistribution\Download`（Windows Updateキャッシュ）
- Chrome / Edge / Firefox / Braveのキャッシュ

### Registry Cleaner

無効なレジストリエントリーを検出・削除します。
管理者権限が必要です。

検出ルール:

| ルール名                 | 判定内容                                          |
| ------------------------ | ------------------------------------------------- |
| `invalidFileReference`   | デフォルト値が存在しないファイルパスを参照        |
| `invalidAppPath`         | Pathプロパティが存在しないファイルパスを参照      |
| `invalidCOMReference`    | InprocServer32/LocalServer32のDLL/EXEが存在しない |
| `invalidTypeLib`         | TypeLibのDLLが存在しない                          |
| `invalidFileAssociation` | ファイル拡張子が存在しないProgIDを参照            |
| `invalidStartupEntry`    | スタートアップのコマンドが存在しないEXEを参照     |
| `invalidMUICache`        | MUIキャッシュが存在しないEXEを参照                |

デフォルトのスキャン対象:

- `SharedDLLs`（存在しないファイルへの参照）
- `App Paths`（存在しないアプリケーションパス）
- `Uninstall`（無効なアンインストール情報）
- `CLSID`（無効なCOMオブジェクト）
- `TypeLib`（無効なタイプライブラリ）
- `HKCR`（無効なファイル関連付け）
- `Run / RunOnce`（無効なスタートアップエントリー）
- `MuiCache`（無効なMUIキャッシュ）

## ログ出力

実行ごとに`logs/`ディレクトリへログファイルが作成されます。

- ファイル名: `win-cleaner_YYYYMMDD_HHmmss.log`
- 記録内容: 分析結果、クリーニング結果、エラー

## 設定のカスタマイズ

`config/settings.json`を編集することで、
削除対象や除外パターンをカスタマイズできます。

### 一時ファイル対象の追加

```json
{
  "tempCleaner": {
    "targets": [
      {
        "category": "分類名",
        "path": "%TEMP%",
        "pattern": "*",
        "recurse": true
      }
    ],
    "excludePatterns": ["*.sys", "*.dll"]
  }
}
```

| キー              | 説明                                               |
| ----------------- | -------------------------------------------------- |
| `category`        | 表示用の分類名                                     |
| `path`            | 対象ディレクトリ（環境変数・ワイルドカード使用可） |
| `pattern`         | ファイル名パターン（ワイルドカード）               |
| `recurse`         | サブディレクトリを再帰検索するか                   |
| `excludePatterns` | 除外するファイル名パターン                         |

### レジストリ対象の追加

```json
{
  "registryCleaner": {
    "targets": [
      {
        "category": "分類名",
        "keyPath": "HKLM:\\SOFTWARE\\...",
        "rule": "invalidFileReference"
      }
    ]
  }
}
```

使用できるルール名は、上記の検出ルール一覧を参照してください。

## ディレクトリ構成

```text
win-cleaner/
├── win-cleaner.ps1                 # エントリーポイント
├── config/
│   └── settings.json               # 設定ファイル
├── modules/
│   ├── Core/                       # 共通基盤
│   │   ├── ICleanerModule.psm1     # モジュールインターフェース
│   │   ├── CleanerEngine.psm1      # モジュール管理エンジン
│   │   ├── PermissionChecker.psm1  # 管理者権限チェック
│   │   ├── SettingsValidator.psm1  # 設定ファイル検証
│   │   └── Logger.psm1             # ログ出力
│   ├── TempCleaner/                # 一時ファイル削除
│   │   ├── TempCleaner.psm1
│   │   └── TempCleanerRule.psm1
│   └── RegistryCleaner/            # レジストリクリーナー
│       ├── RegistryCleaner.psm1
│       └── RegistryCleanerRule.psm1
├── tests/                          # Pesterテスト
├── docs/                           # ドキュメント
│   ├── 基本設計書.md
│   ├── 詳細設計書.md
│   └── 開発ガイド.md
├── logs/                           # 実行ログ出力先
├── PSScriptAnalyzerSettings.psd1   # 静的解析設定
└── LICENSE                         # MITライセンス
```

## テスト

```powershell
# Pesterがインストールされていない場合
Install-Module -Name Pester -Force -SkipPublisherCheck

# テスト実行
Invoke-Pester -Path .\tests\ -Output Detailed
```

## トラブルシューティング

### 実行ポリシーエラー

スクリプト実行時に以下のエラーが出る場合:

```text
このシステムではスクリプトの実行が無効になっています
```

実行ポリシーを変更してください。

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 管理者権限が必要な場合

Registry Cleanerは管理者権限が必要です。
PowerShellを「管理者として実行」から起動してください。

### ロック中のファイルによるエラー

Temp Cleanerで「being used by another process」エラーが
発生する場合があります。
これは他のプロセスが使用中のファイルであり、正常な動作です。
該当ファイルはスキップされ、削除可能なファイルのみ処理されます。

### ログファイルの確認

問題が発生した場合は、`logs/`ディレクトリのログファイルを
確認してください。
ログにはエラーの詳細と対象ファイルのパスが記録されています。

```powershell
# 最新のログファイルを確認
Get-ChildItem .\logs\ | Sort-Object LastWriteTime -Descending |
  Select-Object -First 1 | Get-Content
```

## ライセンス

[MIT License](LICENSE)
