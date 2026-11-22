# aip-proto

Two [Agent Skills](https://agentskills.io/specification) that check protobuf / gRPC APIs against Google's
[API Improvement Proposals](https://google.aip.dev/general) (AIPs): one for writing new `.proto` files, one for
auditing existing ones. They work in Claude Code, OpenAI Codex, Gemini CLI, Cursor, GitHub Copilot, OpenCode and
any other client that reads `SKILL.md` folders, with any model.

The automated layer is Google's own [`api-linter`](https://github.com/googleapis/api-linter). In v2.4.1 it has
340 rules covering 46 of the 73 general AIPs. The skills run it rather than imitate it. The second layer is a
38-item checklist that the agent works through by reading the protos and, when available, the server code. It
covers what the linter cannot see. In this repository's own test fixture, the linter reports 42 findings but
misses that `Book` is a resource identified by `int64 bookID`, and that `int64 created` is a timestamp stored
as an integer. The checklist catches both ([worked report](docs/examples/AIP-AUDIT.fixture.md)).

> This is an independent, unofficial project. It is not affiliated with or endorsed by Google. A "CERTIFIED"
> verdict is a self-assessment against public guidance.

## Contents

- [Requirements](#requirements)
- [Install in Claude Code (plugin)](#install-in-claude-code-plugin)
- [Using the skills](#using-the-skills)
- [Install in other clients](#install-in-other-clients)
- [What it does](#what-it-does)
- [The lint script on its own](#the-lint-script-on-its-own)
- [What it does not do](#what-it-does-not-do)
- [Documentation](#documentation)
- [Repository layout](#repository-layout)

## Requirements

The agent needs a shell tool that can run `bash`. Every client listed below has one. On the machine:

| Tool | Needed for | Install |
|---|---|---|
| **api-linter** | the automated layer (required) | `go install github.com/googleapis/api-linter/v2/cmd/api-linter@latest` (needs Go) |
| **buf** | downloading the `google/api/*.proto` imports once; compatibility checks with `--against` | [buf.build/docs/installation](https://buf.build/docs/installation) |
| bash, find, grep, sed | the wrapper script | preinstalled on Linux and macOS; on Windows use WSL or Git Bash |

If you already have a googleapis checkout, set `AIP_GOOGLEAPIS=/path/to/googleapis` and buf becomes optional.
The first run without it downloads the imports into `~/.cache/aip-proto/googleapis`.

Check your setup:

```bash
api-linter --version          # api-linter 2.4.1 or later
buf --version
```

Without api-linter, `aip-audit` still does the manual review, but its verdict is always NOT CERTIFIED, and
`aip-design` will not claim that a proto is lint-clean.

## Install in Claude Code (plugin)

Inside a Claude Code session:

```
/plugin marketplace add RustLangLatam/aip-proto
/plugin install aip-proto@aip-proto
```

Or from a terminal:

```bash
claude plugin marketplace add RustLangLatam/aip-proto
claude plugin install aip-proto@aip-proto
```

Start a new session afterwards so the skills are loaded. Add `--scope project` to `install` to enable them for
the current repository only. The setting is written to `.claude/settings.json`, so collaborators get it too.

**Without the plugin system**, copy both folders:

```bash
git clone https://github.com/RustLangLatam/aip-proto.git
cp -r aip-proto/skills/aip-design aip-proto/skills/aip-audit ~/.claude/skills/
```

## Using the skills

### Automatic use (the default)

You do not need to name them. `aip-design` loads when you ask to create, design, scaffold or extend a `.proto`
or gRPC API. `aip-audit` loads when you ask to audit, review, lint, validate or certify protos, or to check AIP
compliance.

### Explicit use

| Installed as | Design | Audit |
|---|---|---|
| Claude Code plugin | `/aip-proto:aip-design` | `/aip-proto:aip-audit` |
| Plain skill (Claude Code, Cursor, Copilot) | `/aip-design` | `/aip-audit` |
| OpenAI Codex | `$aip-design` | `$aip-audit` |
| OpenCode | `@aip-design` | `@aip-audit` |
| Gemini CLI | automatic; it asks you to activate the skill | same |

Examples:

```
Design a gRPC API for invoices: customers own invoices, list with filtering by status, and an async PDF export.
Add a Shelf resource with Get and List to proto/acme/library/v1/library.proto.
Audit proto/ for AIP compliance and write AIP-AUDIT.md.
Audit only the protos changed on this branch, against main, in strict mode. The server code is in internal/server.
Audit api/ and fix what you can without breaking v1 clients.
```

### What you will see

**When you design**, the agent first writes down the resource model: resources, parents, resource name patterns,
type names, which standard methods each resource gets, and which operations need a custom method or a
long-running operation. If the domain is ambiguous, it asks you about it. Then it copies the
[lint-clean template](skills/aip-design/assets/acme/library/v1/library.proto), adapts it, and runs the linter
until there are 0 findings. It ends by listing what it left out and the behaviour your server must implement (for
example `update_mask` semantics).

**When you audit**, it runs the linter and walks the
[checklist](skills/aip-audit/references/manual-review.md). Each item gets PASS / FAIL / N/A / NOT VERIFIED, with
a file:line reference. The result is an `AIP-AUDIT.md` in [this format](docs/examples/AIP-AUDIT.fixture.md):
verdict, blocking findings with fixes, warnings, justified disables, and the full checklist. If you ask for fixes
on a published API, it adds and deprecates rather than renaming or renumbering, because those break clients
(AIP-180).

### Managing it

| Task | Command |
|---|---|
| Check that it is installed | `claude plugin list` |
| Update | `claude plugin marketplace update aip-proto` then `claude plugin update aip-proto@aip-proto` |
| Turn off temporarily | `claude plugin disable aip-proto@aip-proto` |
| Turn back on | `claude plugin enable aip-proto@aip-proto` |
| Uninstall | `claude plugin uninstall aip-proto@aip-proto` |

Inside a session, `/plugin` opens the same options interactively.

## Install in other clients

Each skill is a standard folder under `skills/`. The frontmatter has only `name`, `description`, `license` and
`compatibility`, and the instructions use no client-specific variables, tools or commands. The script paths are
relative to each `SKILL.md`, so the skills work from whatever directory your client loads them. The plugin
manifests in `.claude-plugin/` are read only by Claude Code, and other clients ignore them.

**Always install both folders side by side.** `aip-design` runs the lint script from `../aip-audit/scripts/`.

**One copy covers most clients.** Codex, Gemini CLI, Cursor and OpenCode all read `~/.agents/skills/`:

```bash
git clone https://github.com/RustLangLatam/aip-proto.git
mkdir -p ~/.agents/skills
cp -r aip-proto/skills/aip-design aip-proto/skills/aip-audit ~/.agents/skills/
```

To install for one repository only, copy them to `<repo>/.agents/skills/` instead. To get updates with
`git pull`, symlink them instead of copying:
`ln -s "$(pwd)/aip-proto/skills/aip-design" "$(pwd)/aip-proto/skills/aip-audit" ~/.agents/skills/`.

| Client | User directory | Project directory | How it is invoked |
|---|---|---|---|
| **Claude Code** | `~/.claude/skills/` (or the plugin) | `.claude/skills/` | Automatic, or `/aip-audit` |
| **OpenAI Codex** | `~/.agents/skills/` | `.agents/skills/` | Automatic, or `$aip-audit`; `/skills` lists them |
| **Gemini CLI** | `~/.gemini/skills/` or `~/.agents/skills/` | `.gemini/skills/` or `.agents/skills/` | Automatic (asks to activate); `/skills list` to check |
| **Cursor** | `~/.cursor/skills/` or `~/.agents/skills/` (also reads `~/.claude/skills/`) | `.cursor/skills/` or `.agents/skills/` | Automatic, or `/aip-audit` in Agent chat |
| **GitHub Copilot** (VS Code) | `~/.copilot/skills/` | `.github/skills/` | Automatic, or `/aip-audit` |
| **OpenCode** | `~/.config/opencode/skills/` or `~/.agents/skills/` (also reads `~/.claude/skills/`) | `.opencode/skills/` or `.agents/skills/` | Automatic, or `@aip-audit` |

Client-specific notes:

- **Gemini CLI** can install straight from GitHub, one skill at a time:
  ```bash
  gemini skills install https://github.com/RustLangLatam/aip-proto.git --path skills/aip-audit
  gemini skills install https://github.com/RustLangLatam/aip-proto.git --path skills/aip-design
  ```
  Google's documentation states that Gemini CLI was succeeded by Antigravity CLI in June 2026. Check that
  client's docs for its current skills path.
- **GitHub Copilot** does not read `~/.agents/skills/`. Copy both folders to `~/.copilot/skills/` or `.github/skills/`.
- **Cursor and OpenCode** already read `~/.claude/skills/`. A plain-skill install for Claude Code works for them
  with no extra step. The Claude Code *plugin* install lives elsewhere, so they do not see it.
- **Clients that ask for approval before shell commands** will prompt for `aip-lint.sh`. Allow-listing it in the client settings stops the prompts.
- **Several clients on one machine:** install once in `~/.agents/skills/`, add a copy (or the plugin) for Claude
  Code and one in `~/.copilot/skills/` for Copilot. Do not leave two copies visible to the same client, or it may
  list the skills twice.

These paths come from each client's documentation as of November 2026
([Agent Skills spec](https://agentskills.io/specification), [Codex](https://developers.openai.com/codex/skills),
[Gemini CLI](https://geminicli.com/docs/cli/skills/), [Cursor](https://cursor.com/docs/context/skills),
[VS Code Copilot](https://code.visualstudio.com/docs/copilot/customization/agent-skills),
[OpenCode](https://opencode.ai/docs/skills)). Clients change quickly. If a path stops working, check the linked
page and open an issue.

## What it does

### aip-audit

1. **Scopes** the proto root (the directory that package paths are relative to). It notes whether the API is
   already published and whether server code is available.
2. **Runs `aip-lint.sh`**: api-linter, plus `buf breaking` when there is a base to compare against.
3. **Walks the checklist**. Its 38 items link 31 AIPs, in five groups:

   | Group | Covers | Example item |
   |---|---|---|
   | R. Resource model | AIP-121–124, 156, 180, 203 | R6: every resource has a `string name` and a resource type, including the ones the linter cannot recognise |
   | M. Methods & behaviour | AIP-134, 136, 151, 154, 155, 158, 160, 163, 164, 217 | M4: an omitted `update_mask` means all populated fields, and `*` means full replacement |
   | F. Fields | AIP-129, 134, 141–143, 147, 149, 203, 210, 216 | F1: a `REQUIRED` field is really required, and `OUTPUT_ONLY` input is cleared, not rejected |
   | E. Errors, auth, retries | AIP-193, 194, 211 | E2: authorization is checked before any validation, so existence is never leaked |
   | C. Compatibility | AIP-180, 185, 213, 215 | C1: nothing removed, renamed, retyped or moved within a major version |

4. **Decides the verdict**:

   | Verdict | Condition |
   |---|---|
   | **CERTIFIED** | 0 linter findings (a disable is allowed only with a written reason), every MUST and SHOULD item PASS or N/A |
   | **CERTIFIED WITH WARNINGS** | 0 linter findings, no MUST item FAIL, and either a SHOULD FAIL or a MUST item NOT VERIFIED |
   | **NOT CERTIFIED** | any linter finding, any MUST FAIL, a breaking change in a stable version, or the linter was not run |

   A proto-only audit, without server code, cannot get past CERTIFIED WITH WARNINGS, because nobody has seen the
   behaviour. MUST and SHOULD follow the wording of each AIP, as checked on 2026-11-22. Optional features (MAY,
   such as `etag` or `request_id`) are N/A when absent, and when present their MUST parts apply. Findings on
   AIP-162 (Draft) and AIP-182 (Reviewing) never block.

5. **Writes `AIP-AUDIT.md`**, and fixes findings if you asked for that.

### aip-design

1. Resource model first (AIP-121/122/123), confirmed with you when the domain is ambiguous.
2. Copy and adapt the template: the package matches the directory, language options are consistent,
   `google.api.resource` is on each resource, `google.api.http` and `method_signature` are on each RPC, and each
   field has a `field_behavior` and a comment.
3. Lint until there are 0 findings. It never suppresses a rule just to reach 0.
4. Hand-off: what was built, what was left out, and the server behaviour still to implement.

A one-page [cheatsheet](skills/aip-design/references/aip-cheatsheet.md) covers the method table (HTTP mapping,
request fields, return types), field naming, LRO, pagination, filtering, etags, idempotency, soft delete and
error codes. Each entry links its AIP.

## The lint script on its own

[`skills/aip-audit/scripts/aip-lint.sh`](skills/aip-audit/scripts/aip-lint.sh) needs no agent, so you can use it
in CI or as a pre-commit hook:

```bash
aip-lint.sh [-o report.json] [--strict] [--against '.git#branch=main,subdir=proto'] <proto_root> [file.proto ...]
```

| Option | Effect |
|---|---|
| `-o FILE` | JSON report path (api-linter's format: `rule_id`, `rule_doc_uri`, `message`, `location`) |
| `--strict` | ignore inline `(-- api-linter: rule=disabled --)` comments |
| `--against REF` | also run `buf breaking` against a git ref or other buf input. Needs buf and a `buf.yaml` in the root. Local paths are relative to where you run the script, so add `,subdir=<root>` when the root is not the repo root |
| `.api-linter.yaml` in the root | picked up automatically as api-linter config |
| `API_LINTER`, `AIP_GOOGLEAPIS` | override the linter binary and the googleapis directory |
| exit code | `0` clean · `1` findings or breaking changes · `2` setup, compile or buf error (a failed comparison is never reported as clean) |

The [technical report, §5](docs/TECHNICAL_REPORT.md#5-tool-reference-aip-lintsh) has the full reference: file
discovery, config format, inline disables, the JSON schema, and ready-made GitHub Actions, GitLab CI and
pre-commit snippets.

## What it does not do

- It does **not** issue a Google certification. The verdict is a self-assessment.
- It does **not** cover REST or OpenAPI-only APIs. AIPs are written around protobuf.
- It does **not** run your service. Behaviour (validation, authorization order, error payloads) is checked by
  reading code. Without that code, those items stay NOT VERIFIED.
- It does **not** follow AIP updates on its own. The checklist reflects google.aip.dev as of 2026-11-22. New
  upstream rules reach the linter first.
- How well different models handle the judgement items, such as "is this custom method justified?", has not
  been measured.
- The client-library AIPs (4200 series) are out of scope.

## Documentation

- [`docs/TECHNICAL_REPORT.md`](docs/TECHNICAL_REPORT.md): the approach (why two layers), how the coverage boundary
  was drawn, the verdict model, portability, execution protocols, the full `aip-lint.sh` reference with CI
  recipes, measured behaviour, threats to validity, and an AIP-by-AIP coverage index.
- [`docs/examples/AIP-AUDIT.fixture.md`](docs/examples/AIP-AUDIT.fixture.md): a complete audit report on the test fixture.
- [`skills/aip-audit/SKILL.md`](skills/aip-audit/SKILL.md), [`skills/aip-design/SKILL.md`](skills/aip-design/SKILL.md): the skills themselves.
- [`CHANGELOG.md`](CHANGELOG.md): release history.

## Repository layout

```
.claude-plugin/
  plugin.json                  Claude Code plugin manifest
  marketplace.json             single-plugin marketplace (enables /plugin marketplace add)
skills/aip-audit/
  SKILL.md                     audit workflow, verdict, report format
  references/manual-review.md  38-item checklist + AIP coverage map
  scripts/aip-lint.sh          api-linter / buf breaking wrapper
skills/aip-design/
  SKILL.md                     design workflow
  references/aip-cheatsheet.md
  assets/acme/library/v1/library.proto   lint-clean template
docs/
  TECHNICAL_REPORT.md
  examples/AIP-AUDIT.fixture.md
tests/
  run.sh                       template lints clean; fixture trips 5 known rules; --against exit codes
  check_docs.py                coverage tables and counts in the docs match the checklist and the linter
  fixtures/violations/…        deliberately non-compliant proto
.github/workflows/test.yml     runs tests/run.sh against the latest api-linter
CITATION.cff · CHANGELOG.md · LICENSE
```

## Contributing

Run `tests/run.sh` before opening a PR. When you add a checklist item, link its AIP, keep the AIP's own MUST or
SHOULD, and add a row to Appendix A of the technical report.

## License

MIT for the skills, script and documentation. The AIP texts at google.aip.dev are © Google, licensed CC BY 4.0.
This repository links to and paraphrases them, but does not copy them.
