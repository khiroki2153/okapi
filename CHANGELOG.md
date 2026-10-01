# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Added
- `okapi extract` command: pulls one request out of a collection into a
  standalone file with inherited headers/query fully resolved, so body/query
  can be edited freely without touching a shared collection.
- Collection-level `headers:` / `query:` inheritance: requests merge these in
  (request-level keys win on conflict), so common headers like `Authorization`
  only need to be written once per collection instead of once per request.
- `okapi import openapi`: imports an OpenAPI 3.x spec (local file, or URL) into
  okapi's collection format, including a `--output-dir` mode that splits the
  result into one collection file per API tag/resource.
- `okapi list` command.
- `okapi run --output stdout`: logs the executed method/URL/status/response
  body to stdout instead of writing a HAR file. Never prints request headers,
  so secrets pulled from the environment file (e.g. `apiToken`) are never
  logged.
- Environment file resolution order for `run` and `env show`: explicit
  `--env` > `$OKAPI_ENV` > `envs/default.yaml`, so a default environment no
  longer needs to be passed on every invocation.
- `okapi -v` / `--version`.
- `collections/okta_management/`: a collection generated from Okta's publicly
  published OpenAPI 3 Management API spec, split per API tag.
- `.claude/skills/okapi/SKILL.md`: a Claude Code skill for operating okapi,
  installable in other repos via `npx skills add khiroki2153/okapi`.

### Fixed
- Importers (Postman and OpenAPI) now deep-copy generated values before
  dumping to YAML. Without this, Ruby's `frozen_string_literal` literal
  interning and shared `$ref`-resolved objects could make `YAML.dump` emit
  anchors/aliases, so hand-editing one imported request could silently
  mutate another request sharing the same anchor.

## [0.1.0]

Initial implementation per `SPEC.md`.

### Added
- YAML collection format with `{{variable}}` interpolation.
- Environment files for managing variables (`baseUrl`, `apiToken`, etc.) across
  multiple orgs.
- Request execution for GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS, plus
  low-priority support for the draft HTTP `QUERY` method.
- HAR 1.2 output (`okapi run --output result.har`), with response bodies
  always stored as plain strings to avoid the "JSON on JSON" problem when
  viewed in browser DevTools.
- Postman Collection v2.1 importer (`okapi import postman`), one-way, for
  migrating existing Postman collections (including Okta's published ones).
- `okapi env show`.

[0.2.0]: https://github.com/khiroki2153/okapi/releases/tag/v0.2.0
[0.1.0]: https://github.com/khiroki2153/okapi/releases/tag/v0.1.0
