---
name: okapi
description: Okta API コレクションを okapi CLI で実行する。環境ファイルから変数（baseUrl, apiToken）を読み込み、SSWS を秘匿したまま API を叩く。
when_to_use: ユーザーが Okta API を検証したいとき、コレクション内のリクエストを実行したいとき
---

# Skill: okapi

## 概要

`okapi` は YAML 形式の API コレクションを管理・実行する Ruby 製 CLI ツール。
環境ファイルで SSWS トークンを管理するため、コレクション YAML にトークンが露出しない。

このスキルは okapi リポジトリ自身に同梱されている（`.claude/skills/okapi/SKILL.md`）。
以下のパスはすべてリポジトリルート基準の相対パス。

## バイナリパス

```
bin/okapi
```

リポジトリルートから `./bin/okapi ...` で呼ぶ。頻繁に使う場合は `bin/` を PATH に
追加しておくと `okapi` だけで呼べる。

## ファイル構成

```
<repo root>/
├── examples/      # サンプルのコレクション・環境ファイル
├── collections/   # 実際に使うリクエストコレクション（YAML, git 管理対象）
└── envs/          # 実際の環境ファイル（YAML, SSWS はここに。git 管理対象外）
```

## 主要コマンド

```bash
# コレクション内のリクエスト一覧を確認
okapi list <collection.yaml>

# 特定リクエストを実行
okapi run <collection.yaml> --env <env.yaml> --request "リクエスト名"

# コレクション内の全リクエストを実行
okapi run <collection.yaml> --env <env.yaml> --all

# 結果を HAR で保存
okapi run <collection.yaml> --env <env.yaml> --request "リクエスト名" --output result.har

# Postman コレクションをインポート
okapi import postman <postman.json> --output <collection.yaml>
```

## 環境ファイルの場所

ユーザーの環境ファイルは以下に格納されている想定：
```
<repo root>/envs/
```

環境ファイルが見つからない場合はユーザーに確認する。

## Procedure

### 通常フロー

1. **コレクションと環境を特定する**
   - ユーザーが「Okta の API を叩いて」「Users API を確認して」等と言った場合、どのコレクションか確認する
   - 環境（sandbox / 本番 / 検証環境）を確認する
   - 必要に応じて `ls collections/` で一覧を出す

2. **リクエストを実行する**
   ```bash
   okapi run <collection> --env <env> --request "<name>"
   ```

3. **結果を報告する**
   - ステータスコード、レスポンスボディの要点をまとめて報告する
   - エラーの場合は原因と対処を提案する

### URL（Confluence / Jira / ドキュメント）を渡されたフロー

ユーザーが URL とともに「これ実行して」「これ検証して」と言った場合：

1. **URL の内容を読んで必要な API を特定する**
   - Confluence: `fetch-okta-kb` または Atlassian MCP でページを読む
   - Jira: Atlassian MCP でチケットを読む
   - developer.okta.com: `WebFetch` で読む

2. **コレクションに該当リクエストがあるか確認する**
   ```bash
   ls collections/
   okapi list <候補のcollection.yaml>
   ```

3. **なければコレクションに追加する**
   - 読み取った API 仕様（エンドポイント・メソッド・パラメータ）を元に YAML エントリを作成
   - 既存の collection.yaml に追記、または新規ファイルを作成
   - ユーザーに追加内容を確認してから実行する

4. **実行して結果を報告する**

## 注意事項

- SSWS トークンは環境ファイルに格納されているため、コマンドや出力に直接表示しない
- 本番 org の API を叩く前にユーザーに確認を取る
- 文末は「！」で締める（Luca キャラクター規約）
