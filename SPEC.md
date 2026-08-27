# okapi — API Collection Manager

## 概要

Ruby 製の CLI ツール。API コレクションを YAML で管理・実行し、結果を HAR 形式で保存する。  
GUI なし。Postman の代替として、主に Okta API の検証・サポート業務に使う。

## 背景・経緯

- Postman が重い・不安定・有料機能の押しつけが増えたので自作
- Bruno を検討したが sudo 要求・Postman import が有料ロックで断念
- コレクションを git 管理したい
- 手書きしやすいフォーマットが欲しい

## 名前

**okapi**（OK + API のダジャレ、動物のオカピも由来）

---

## 機能要件

### コレクション管理
- YAML ファイルでリクエストを定義（ネイティブフォーマット）
- ディレクトリ構造でコレクションを整理
- Postman Collection v2.1 JSON からのインポート（一方向、移行用）
- Okta が公開している Postman コレクションのインポートも対象

### リクエスト実行
- HTTP メソッド：GET / POST / PUT / PATCH / DELETE / HEAD / OPTIONS
- HTTP QUERY メソッド（RFC draft）対応（低優先度）
- 変数の補間（`{{変数名}}` 形式）
- ヘッダー設定
- リクエストボディ設定（JSON, form-data 等）
- クエリパラメータ設定

### 環境・変数管理
- 環境ファイル（YAML）で変数を管理
- 複数環境の切り替え（例：sandbox org、本番 org）
- 典型的な変数：`baseUrl`, `apiToken`, `orgDomain` 等

### 結果保存
- **HAR 形式**（HTTP Archive）で保存
- ブラウザの DevTools（Chrome/Firefox）でそのまま開いて閲覧可能
- レスポンスボディが JSON でも HAR 内では文字列として格納されるため「JSON on JSON」問題が発生しない

---

## コレクション YAML フォーマット（案）

```yaml
name: Okta Users API
description: ユーザー管理系のリクエスト集

requests:
  - name: List Users
    method: GET
    url: "{{baseUrl}}/api/v1/users"
    headers:
      Authorization: "SSWS {{apiToken}}"
      Accept: application/json
    query:
      limit: 25
      filter: 'status eq "ACTIVE"'

  - name: Create User
    method: POST
    url: "{{baseUrl}}/api/v1/users"
    headers:
      Authorization: "SSWS {{apiToken}}"
      Content-Type: application/json
    body:
      type: json
      content:
        profile:
          firstName: John
          lastName: Doe
          email: john.doe@example.com
          login: john.doe@example.com
        credentials:
          password:
            value: "TempPass1234!"
```

## 環境ファイル YAML フォーマット（案）

```yaml
# environments/sandbox.yaml
name: Sandbox
variables:
  baseUrl: https://dev-12345678.okta.com
  apiToken: 00xxxxxxxxxxxxxxxxxxxxx
```

---

## CLI インターフェース（案）

```bash
# リクエスト実行
okapi run <collection.yaml> --env <environment.yaml> --request "List Users"

# コレクション内の全リクエスト実行
okapi run <collection.yaml> --env <environment.yaml> --all

# 結果を HAR で保存
okapi run <collection.yaml> --env <environment.yaml> --request "List Users" --output result.har

# Postman コレクションのインポート
okapi import postman <postman_collection.json> --output <collection.yaml>

# 変数一覧の確認
okapi env show <environment.yaml>
```

---

## 技術スタック

- **言語**：Ruby
- **HTTP クライアント**：`net/http`（標準ライブラリ）または `faraday` gem
- **YAML パース**：`yaml`（標準ライブラリ）
- **JSON パース**：`json`（標準ライブラリ）
- **HAR 出力**：手実装（HAR は単純な JSON スキーマ）
- **CLI**：`thor` gem または `optparse`（標準ライブラリ）

---

## ディレクトリ構成（案）

```
okapi/
├── bin/
│   └── okapi               # 実行エントリポイント
├── lib/
│   └── okapi/
│       ├── runner.rb       # リクエスト実行
│       ├── collection.rb   # コレクション読み込み・パース
│       ├── environment.rb  # 環境・変数管理
│       ├── har.rb          # HAR 形式での出力
│       └── importer/
│           └── postman.rb  # Postman v2.1 インポーター
├── spec/                   # テスト
├── examples/
│   ├── okta_users.yaml     # サンプルコレクション
│   └── sandbox.yaml        # サンプル環境ファイル
├── SPEC.md                 # このファイル
└── README.md
```

---

## 優先実装順

1. YAML コレクション読み込み + 変数補間
2. GET / POST / PUT / DELETE 実行
3. HAR 出力
4. 環境ファイル対応
5. Postman v2.1 インポーター
6. QUERY メソッド（低優先）

---

## 参考資料

- [HAR 1.2 仕様](http://www.softwareishard.com/blog/har-12-spec/)
- [Postman Collection Format v2.1](https://schema.postman.com/collection/json/v2.1.0/draft-07/docs/)
- [Okta Postman コレクション](https://www.postman.com/oktadev)
- [HTTP QUERY Method RFC draft](https://www.ietf.org/archive/id/draft-ietf-httpbis-safe-method-w-body-02.txt)
