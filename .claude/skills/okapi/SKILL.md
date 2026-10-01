---
name: okapi
description: Okta API コレクションを okapi CLI で実行する。環境ファイルから変数（baseUrl, apiToken）を読み込み、SSWS を秘匿したまま API を叩く。
when_to_use: ユーザーが「API で〇〇して」「〇〇 API を叩いて」「〇〇を検証して」「ユーザー XX に対して YY を実行して」など、Okta API の実行・検証を依頼したとき。常にこのスキルを使う。
---

# Skill: okapi

## 概要

`okapi` は YAML 形式の API コレクションを管理・実行する Ruby 製 CLI ツール。
環境ファイルで SSWS トークンを管理するため、コレクション YAML にトークンが露出しない。
詳細は okapi リポジトリの README.md / SPEC.md を参照。

このスキルは okapi リポジトリ自身に同梱されている（`.claude/skills/okapi/SKILL.md`）。
以下のパスはすべて **okapi リポジトリのルート基準の相対パス**。okapi リポジトリの
外から呼ばれた場合は、まず okapi リポジトリのルートに `cd` してから以下のコマンドを
実行する。

## バイナリパス

```
bin/okapi
```

リポジトリルートで `./bin/okapi ...`、または `bin/` を PATH に追加していれば
`okapi ...` で呼べる。PATH が通っているか不明な場合は、確実に動く
`cd <okapi リポジトリ> && bin/okapi ...` を使う。

## ファイル構成

```
<okapi リポジトリルート>/
├── bin/okapi          # CLI バイナリ
├── collections/       # 共通リクエストコレクション（YAML, git 管理対象）
│   └── <api>/         # OpenAPI spec などから生成した API 単位のコレクション群
├── cases/             # アドホックな検証用の一時コレクション（git 管理対象外）
│   └── <identifier>.yaml / .har
├── envs/              # 環境ファイル（YAML, SSWS はここに。git 管理対象外）
│   └── default.yaml   # デフォルト環境（--env 省略時に自動適用。$OKAPI_ENV でも指定可）
└── examples/          # サンプルのコレクション・環境ファイル
```

`collections/` と `cases/` の違い：`collections/` は再利用する共通コレクション
（git 管理対象）、`cases/` は一回限りの調査・検証用に作る一時ファイル（git 管理対象外）。

## 主要コマンド

```bash
# コレクション内のリクエスト一覧を確認
bin/okapi list <collection.yaml>

# 特定リクエストを実行（--env 省略時は $OKAPI_ENV → envs/default.yaml の順で解決）
bin/okapi run <collection.yaml> --request "リクエスト名"
bin/okapi run <collection.yaml> --env <env.yaml> --request "リクエスト名"

# コレクション内の全リクエストを実行
bin/okapi run <collection.yaml> --all

# 結果を HAR ファイルに保存
bin/okapi run <collection.yaml> --request "リクエスト名" --output result.har

# 実行したエンドポイント・結果を stdout にログ出力（変数の値は出さない。HAR 保存不要なとき向け）
bin/okapi run <collection.yaml> --request "リクエスト名" --output stdout

# 1 リクエストを継承済みヘッダー展開済みの単独ファイルに書き出す
# （body/query を編集したいが、共有コレクションを直接触りたくないとき）
bin/okapi extract <collection.yaml> --request "リクエスト名" --output <file.yaml>

# Postman / OpenAPI 3 コレクションをインポート
bin/okapi import postman <postman.json> --output <collection.yaml>
bin/okapi import openapi <spec.yaml|URL> --output-dir <dir>   # タグ単位で分割インポート

# 環境ファイルの変数一覧を表示
bin/okapi env show
```

## コレクション YAML フォーマットと headers/query 継承

```yaml
name: コレクション名
headers:                      # 全リクエスト共通ヘッダー（各リクエストに継承される）
  Authorization: SSWS {{apiToken}}
  Accept: application/json
requests:
  - name: リクエスト名
    method: POST
    url: "{{baseUrl}}/api/v1/users/{{userId}}/lifecycle/expire_password_with_temp_password"
  - name: 別のリクエスト
    method: PUT
    url: "{{baseUrl}}/api/v1/users/{{userId}}"
    headers:
      Content-Type: application/json  # 追加ヘッダー（共通ヘッダーに上書きマージ、同名キーのみ上書き）
    body:
      type: json
      content:
        credentials:
          password:
            value: "newPassword123"
```

- コレクションのトップレベルの `headers:` / `query:` は各リクエストにキー単位で
  継承される（リクエスト側に同名キーがあればそちらが優先、他のキーは継承のまま）
- `{{apiToken}}` / `{{baseUrl}}` のような変数は環境ファイル（`envs/default.yaml` など）
  の `variables:` から解決される
- YAML をそのまま読むときは注意：`headers:` が無いリクエストも、コレクション
  レベルの継承により実際には Authorization 等を持っている。継承後の実値を見たい
  ときは `bin/okapi list` や `bin/okapi extract` を使う

## Procedure

### A. アドホックな API 実行（ユーザーが「〇〇 API を叩いて」と言ったとき）

**最も多いパターン。迷わずこのフローを使う。**

1. **必要な API を既存コレクションから探す**
   ```bash
   grep -rl "<キーワード>" collections/
   ```
   見つかればそのコレクションを使う（必要なら `bin/okapi extract` で単独ファイルに
   してから編集）。見つからなければステップ 2 へ。

2. **cases/ にコレクションファイルを作成する**
   - ファイル名: `cases/<わかりやすい識別子>.yaml`（ケース番号、チケット番号など）
   - 具体的なユーザー ID・パラメータをハードコードしてよい（一時ファイルのため）
   ```yaml
   name: <目的の説明>
   headers:
     Authorization: SSWS {{apiToken}}
     Accept: application/json
   requests:
     - name: <リクエスト名>
       method: POST
       url: "{{baseUrl}}/api/v1/users/<userId>/lifecycle/..."
   ```

3. **実行する**
   ```bash
   bin/okapi run cases/<file>.yaml --request "<name>" --output cases/<file>.har
   # または stdout で確認するだけなら
   bin/okapi run cases/<file>.yaml --request "<name>" --output stdout
   ```

4. **結果を報告する**
   - ステータスコード・レスポンスボディの要点をまとめて報告する
   - HAR から読み取る場合：
     ```bash
     ruby -rjson -e 'h=JSON.parse(File.read("cases/<file>.har")); e=h["log"]["entries"][0]; puts "Status: #{e["response"]["status"]}"; puts "Body: #{e["response"]["content"]["text"]}"'
     ```
   - エラーの場合は原因と対処を提案する

### B. 既存コレクションのリクエストを実行する

```bash
bin/okapi list collections/<api>/<resource>.yaml       # 一覧確認
bin/okapi run collections/<api>/<resource>.yaml --request "<リクエスト名>" --output stdout
```

### C. URL や仕様を渡されて「これを実行して」と言われたとき

1. URL を読んで必要な API を特定する（Confluence/Jira は該当 MCP、
   developer.okta.com などの一般的なページは `WebFetch`）
2. `collections/` に既存リクエストがあるか確認する（手順 A のステップ 1 と同様）
3. なければ `cases/` に YAML を作成してから実行する（手順 A のステップ 2 以降）
4. 結果を報告する

## 注意事項

- SSWS トークンは環境ファイルに格納されているため、コマンドや出力に直接表示しない
- 本番 org の API を叩く前にユーザーに確認を取る
