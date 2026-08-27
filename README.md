# okapi

GUI なしの API コレクション管理 CLI（Ruby 製）。Postman の代替として、リクエストを
YAML で管理し、実行結果を HAR 形式で保存する。詳細な背景は [SPEC.md](SPEC.md) を参照。

依存は Ruby 標準ライブラリのみ（`optparse` / `net/http` / `yaml` / `json`）。
`gem install` や `bundle install` は不要。

## セットアップ

```bash
chmod +x bin/okapi
export PATH="$PWD/bin:$PATH"   # or call ./bin/okapi directly
```

## 使い方

```bash
# コレクション内のリクエスト一覧を確認
okapi list examples/okta_users.yaml

# コレクション内の単一リクエストを実行
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --request "List Users"

# コレクション内の全リクエストを実行
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --all

# 実行結果を HAR ファイルに保存（Chrome/Firefox の DevTools でそのまま開ける）
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --all --output result.har

# Postman Collection v2.1 JSON をインポート
okapi import postman postman_collection.json --output collection.yaml

# OpenAPI 3 spec をインポート（ローカルファイル or URL、1 ファイルにまとめる）
okapi import openapi spec.yaml --output collection.yaml
okapi import openapi spec.yaml --output collection.yaml --tag User   # 特定タグのみ

# OpenAPI 3 spec を API のタグ（リソース種別）ごとに分割してインポート
okapi import openapi spec.yaml --output-dir collections/some_api

# 環境ファイルの変数一覧を表示
okapi env show examples/sandbox.yaml
```

### Okta Management API コレクション

`collections/okta_management/` は Okta が公式に公開している OpenAPI 3 spec
（[okta/okta-management-openapi-spec](https://github.com/okta/okta-management-openapi-spec)）
から `okapi import openapi --output-dir` で生成した、developer.okta.com の
API リファレンスと同じ粒度（User / Group / Application 等のタグ単位）に分割
された全 734 リクエストのコレクション。再生成するには：

```bash
curl -sL -o /tmp/okta_mgmt.yaml \
  https://raw.githubusercontent.com/okta/okta-management-openapi-spec/master/dist/current/management-minimal.yaml
okapi import openapi /tmp/okta_mgmt.yaml --output-dir collections/okta_management
```

## コレクション / 環境ファイルのフォーマット

`SPEC.md` の「コレクション YAML フォーマット」「環境ファイル YAML フォーマット」を
参照。サンプルは `examples/okta_users.yaml` と `examples/sandbox.yaml`。

実運用のコレクション・環境ファイルは以下に置く想定：

- `collections/` — 実際に使うコレクション YAML（git 管理対象）
- `envs/` — 実際の SSWS トークン等を含む環境 YAML（**git 管理対象外**。`.gitignore` 済み）

## 開発

```bash
rake test   # spec/**/*_spec.rb を minitest で実行
```

`spec/runner_spec.rb` はモックライブラリを使わず、プレーンな `TCPServer` を
テスト用のフェイク HTTP サーバーとして起動して実リクエストを検証する。
