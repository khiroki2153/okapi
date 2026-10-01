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

### Claude Code スキルとして使う

このリポジトリには `.claude/skills/okapi/SKILL.md` が同梱されている。
[skills.sh](https://skills.sh)（[vercel-labs/skills](https://github.com/vercel-labs/skills)）
経由で他リポジトリに取り込める：

```bash
npx skills add khiroki2153/okapi
```

スキル自体は okapi 本体（この CLI）がローカルに存在することを前提にしている
（スキル単体では動作しない）。

## 使い方

```bash
# コレクション内のリクエスト一覧を確認
okapi list examples/okta_users.yaml

# コレクション内の 1 リクエストを、継承済みの headers/query を展開した状態で
# 単独ファイルとして書き出す（body/query を自由に編集したいとき用。元のコレクションは変更しない）
okapi extract examples/okta_users.yaml --request "List Users" --output list_users.yaml

# コレクション内の単一リクエストを実行（--env を省略すると後述の解決順序に従う）
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --request "List Users"

# コレクション内の全リクエストを実行
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --all

# 実行結果を HAR ファイルに保存（Chrome/Firefox の DevTools でそのまま開ける）
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --all --output result.har

# 実行したエンドポイントと結果を stdout にログ出力（変数の値・ヘッダーは出力しない）
okapi run examples/okta_users.yaml --env examples/sandbox.yaml --all --output stdout

# Postman Collection v2.1 JSON をインポート
okapi import postman postman_collection.json --output collection.yaml

# OpenAPI 3 spec をインポート（ローカルファイル or URL、1 ファイルにまとめる）
okapi import openapi spec.yaml --output collection.yaml
okapi import openapi spec.yaml --output collection.yaml --tag User   # 特定タグのみ

# OpenAPI 3 spec を API のタグ（リソース種別）ごとに分割してインポート
okapi import openapi spec.yaml --output-dir collections/some_api

# 環境ファイルの変数一覧を表示（引数省略時も同じ解決順序に従う）
okapi env show examples/sandbox.yaml

# バージョン表示
okapi --version
```

### 環境ファイルの解決順序

`run` と `env show` は、`--env` を省略すると以下の優先順位で環境ファイルを探す：

1. `--env <file>`（明示指定）
2. `$OKAPI_ENV` 環境変数
3. `envs/default.yaml`（カレントディレクトリ基準）

普段使う環境を毎回 `--env` で指定しなくていいように、シェルの profile で
`export OKAPI_ENV=/path/to/envs/sandbox.yaml` するか、`envs/default.yaml` を
使いたい環境ファイルのコピー（またはシンボリックリンク）にしておく。別の org
を一時的に叩きたいときだけ `--env` で上書きすればよい。

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

### headers / query の継承

コレクションのトップレベルにも `headers:` / `query:` を書ける。各リクエストは
そのキーを継承し、リクエスト側で同名キーを書いた場合はそちらが優先される
（キー単位のマージなので、他のキーは引き続き継承される）：

```yaml
name: Okta Users API
headers:
  Authorization: "SSWS {{apiToken}}"
  Accept: application/json

requests:
  - name: List Users
    method: GET
    url: "{{baseUrl}}/api/v1/users"
    # headers 未指定 → Authorization / Accept をそのまま継承

  - name: Create User
    method: POST
    url: "{{baseUrl}}/api/v1/users"
    headers:
      Content-Type: application/json   # Authorization / Accept は継承したまま追加
```

`Authorization` のように全リクエスト共通のヘッダーを毎回書かなくて済むので、
特に自動生成した数百リクエスト規模のコレクションで効果が大きい。
`collections/okta_management/user.yaml` などが実例。

body や query を編集したいときにこの共有ファイルを直接触ると他のリクエストにも
影響するので、その場合は `okapi extract` で継承済みの単独ファイルに書き出してから
編集するとよい（上記の使い方を参照）。

実運用のコレクション・環境ファイルは以下に置く想定：

- `collections/` — 実際に使うコレクション YAML（git 管理対象）
- `envs/` — 実際の SSWS トークン等を含む環境 YAML（**git 管理対象外**。`.gitignore` 済み）

## 開発

```bash
rake test   # spec/**/*_spec.rb を minitest で実行
```

`spec/runner_spec.rb` はモックライブラリを使わず、プレーンな `TCPServer` を
テスト用のフェイク HTTP サーバーとして起動して実リクエストを検証する。

## バージョニング

[Semantic Versioning](https://semver.org/) に従う。現在のバージョンは
`lib/okapi/version.rb` の `Okapi::VERSION`（`okapi --version` で表示）で、
リリースごとに同じバージョンで git tag（`vX.Y.Z`）を打つ。変更履歴は
[CHANGELOG.md](CHANGELOG.md) を参照。

## ライセンス

[Apache License 2.0](LICENSE)
