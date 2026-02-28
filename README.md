# Windows Cleaner

Windows環境の不要ファイルやレジストリエントリーを検出・削除するPowerShell製CLIツール。

## 特徴

- **軽量**: PowerShell 5.1のみで動作し、追加インストール不要
- **安全**: 削除前に分析結果を表示し、ユーザー確認を必須とする
- **拡張可能**: SOLID原則に基づくモジュール設計

## 動作環境

| 項目 | 要件 |
| --- | --- |
| OS | Windows 10 / 11 |
| PowerShell | 5.1以上 |
| 権限 | 一時ファイル削除：一般ユーザー / レジストリ操作：管理者 |

## 使い方

```powershell
# 通常実行
.\win-cleaner.ps1

# レジストリクリーナーを使う場合は管理者権限で実行
# PowerShellを「管理者として実行」してから
.\win-cleaner.ps1
```

起動するとメニューが表示されます。

```text
========================================
  Windows Cleaner v0.1.0
========================================

Available modules:

  1. Temp Cleaner
     Delete temporary files and caches
  2. Registry Cleaner [Admin]
     Detect and remove invalid registry entries

  0. Exit

Select module:
```

モジュールを選択すると、分析結果が表示され`y/N`の確認後にクリーニングが実行されます。

## モジュール一覧

### Temp Cleaner

一時ファイルやキャッシュを検出・削除します。管理者権限は不要です。

デフォルトの対象:

- `%TEMP%`（ユーザーTempフォルダ）
- `%SystemRoot%\Temp`（システムTempフォルダ）
- `%SystemRoot%\Prefetch`（プリフェッチファイル）
- `%SystemRoot%\SoftwareDistribution\Download`（Windows Updateキャッシュ）

### Registry Cleaner

無効なレジストリエントリーを検出・削除します。管理者権限が必要です。

デフォルトの対象:

- `SharedDLLs`（存在しないファイルへの参照）
- `App Paths`（存在しないアプリケーションパス）
- `Uninstall`（無効なアンインストール情報）

## 設定のカスタマイズ

`config/settings.json`を編集することで、削除対象や除外パターンをカスタマイズできます。

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

| キー | 説明 |
| --- | --- |
| category | 表示用の分類名 |
| path | 対象ディレクトリ（環境変数使用可） |
| pattern | ファイル名パターン（ワイルドカード） |
| recurse | サブディレクトリを再帰検索するか |
| excludePatterns | 除外するファイル名パターン |

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

| ルール名 | 判定内容 |
| --- | --- |
| invalidFileReference | デフォルト値が存在しないファイルパスを参照 |
| invalidAppPath | Pathプロパティが存在しないファイルパスを参照 |

## ディレクトリ構成

```text
win-cleaner/
├── win-cleaner.ps1              # エントリーポイント
├── modules/
│   ├── Core/                    # 共通基盤
│   │   ├── ICleanerModule.psm1
│   │   ├── CleanerEngine.psm1
│   │   └── PermissionChecker.psm1
│   ├── TempCleaner/             # 一時ファイル削除
│   │   ├── TempCleaner.psm1
│   │   └── TempCleanerRule.psm1
│   └── RegistryCleaner/         # レジストリクリーナー
│       ├── RegistryCleaner.psm1
│       └── RegistryCleanerRule.psm1
├── config/
│   └── settings.json            # 設定ファイル
├── docs/                        # 設計書
│   ├── 基本設計書.md
│   └── 詳細設計書.md
└── tests/                       # Pesterテスト
```

## テスト

```powershell
# Pesterがインストールされていない場合
Install-Module -Name Pester -Force -SkipPublisherCheck

# テスト実行
Invoke-Pester -Path .\tests\ -Output Detailed
```

## 新しいモジュールの追加方法

1. `modules/`配下に新しいディレクトリを作成する
2. `ICleanerModule`を継承したクラスを実装する
3. `win-cleaner.ps1`の`Start-WinCleaner`関数内に`$engine.Register(...)`を1行追加する
