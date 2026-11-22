# aip-proto: Two-Layer AIP Conformance Checking for Protocol Buffer APIs with LLM Agents

**Technical Report — v0.2.0 — November 2026**

*Independent, unofficial work. Not affiliated with or endorsed by Google. "Certified" in this document means
self-assessed against public guidance.*

---

## Abstract

Google's official AIP linter, `api-linter` v2.4.1, ships 340 `core` rules. They touch 46 of the 73 AIPs listed
on google.aip.dev/general. Of the other 27, eight are process or meta documents that have no counterpart in code.
Most of the remaining nineteen describe semantics or server behaviour that a linter cannot read from a
descriptor: error payloads (AIP-193), checking authorization before existence (AIP-211), compatibility across
releases (AIP-180), what `update_mask` actually does (AIP-161). Even for the AIPs it covers, the linter
recognises resources by the presence of a `name` field, so an API built on `int64 id` slips past most of the
resource rules.

This report describes **aip-proto**, two Agent Skills that put the linter and an LLM to work in turn.
`aip-audit` runs the linter, then has the agent walk a 38-item checklist of the gaps, and issues a three-level
verdict. `aip-design` takes the agent from a resource model, through a lint-clean template, to zero findings.
Both are plain `SKILL.md` folders plus one bash script, and both run unchanged in Claude Code, OpenAI Codex,
Gemini CLI, Cursor, GitHub Copilot and OpenCode. The repository's tests show the template at 0 findings, a
negative fixture at 42, and two real linter blind spots in that fixture which only the manual layer reports. No
user study or accuracy evaluation of the manual layer is included in this release.

**Keywords:** API design, Protocol Buffers, gRPC, AIP, api-linter, Agent Skills, LLM agents, conformance.

---

## 1. Introduction

The negative fixture in this repository (`tests/fixtures/violations/…/library.proto`, 55 lines) trips 42 linter
findings. Two defects that a human reviewer would flag first are not among them:

1. `message Book { int64 bookID = 1; … }` has no resource name and no `google.api.resource`. The resource rules
   (AIP-122/123) trigger on messages that have `name`, so the linter never treats `Book` as a resource.
2. `int64 created = 3;` stores a point in time as an integer. The AIP-142 rules key on field names such as the
   `_time` suffix, and `created` matches none of them.

Both are caught in the manual layer, by checklist items R6 (AIP-122/123, MUST) and F3b (AIP-142, SHOULD)
([worked report](examples/AIP-AUDIT.fixture.md)). That pattern repeats across the AIPs, and it is why the
project has two layers.

We take two positions from it:

> **P1 (Delegate the mechanical).** Anything `api-linter` checks is checked by running `api-linter`. The skills
> never re-derive a linter rule by reading the proto. A reimplementation would drift from upstream, and an LLM
> reading 340 rules is slower and less reliable than the binary.

> **P2 (Reason about the rest).** The LLM is used only where a descriptor is not enough: intent (is this custom
> method justified?), server behaviour (does `REQUIRED` get validated?), and history (does this break v1
> clients?).

The contribution is engineering. We run no experiments on agent accuracy. We document how the coverage boundary
was drawn (§3, Appendix A) so anyone can check it.

## 2. Source Material

### 2.1 The AIP programme

API Improvement Proposals (google.aip.dev) are Google's design guidance for resource-oriented APIs, written
around Protocol Buffers and gRPC, with HTTP/JSON transcoding (AIP-127). The general index (fetched 2026-11-22)
lists 73 AIPs in ten areas: Meta, Process, API Concepts, Resource Design, Operations, Fields, Design Patterns,
Compatibility and Versioning, Polish, and Protocol Buffers. AIP-162 (Resource Revisions) is marked Draft and
AIP-182 (External software dependencies) is marked Reviewing. None is marked deprecated. The AIPs use RFC 2119
keywords (MUST, SHOULD, MAY), which the checklist keeps.

### 2.2 api-linter

`github.com/googleapis/api-linter` is Google's linter for those AIPs. Version 2.4.1 (Go module path `…/v2`)
lists 342 rules: 340 under `core::NNNN::…` plus 2 under `client-libraries::4232::…`. It compiles the protos
itself, so it needs every import resolvable, including `google/api/*.proto`. Rules can be configured per path
in a YAML/JSON config file, or turned off inline with `(-- api-linter: <rule>=disabled --)` comments, which
`--ignore-comment-disables` overrides. It can print YAML, JSON, GitHub annotations or a summary table.

### 2.3 buf

`buf breaking` compares a module with an earlier version (for example a git ref) and reports changes that break
wire or source compatibility. It is the automated part of AIP-180. aip-proto also uses `buf export` once, to fetch
the googleapis protos that api-linter needs.

## 3. Method

### 3.1 Drawing the coverage boundary

`api-linter --list-rules` was grouped by AIP number (Appendix A). Every AIP on the general index was then put in
one of three classes:

| Class | Meaning | Count |
|---|---|---|
| **L** | the linter has rules for it | 46 AIPs |
| **M** | it has checklist items, with or without linter rules | 38 items linking 31 AIPs |
| **—** | process or meta, with nothing to check in code | 8 AIPs (1, 2, 3, 8, 9, 100, 200, 205) |

The classes overlap: an AIP can have rules and items both (Appendix A). AIP-111 (planes) is a concept document.
The audit mentions it when an API splits management and data planes, but it has no checklist item.

### 3.2 Writing checklist items

An item was written only when it met three conditions:

1. The AIP states the requirement with MUST, SHOULD or MAY, and the item keeps that strength. Where an AIP mixes
   strengths, the item is split. For example, M6 (MUST) requires opaque page tokens, M6b (SHOULD) requires a
   documented default page size that is coerced rather than rejected, and M6c (MUST) requires `INVALID_ARGUMENT`
   for a negative size. Optional features get the strength **MAY → MUST**: the feature is optional, but its
   MUST rules apply once it is offered. One example is M5: `etag` is optional, but a stale etag must fail with
   `ABORTED`.
2. No linter rule decides it fully. Where a rule exists but checks only syntax (for example `field_behavior` is
   *present*), the item checks semantics (F1: the annotation is *true*).
3. An agent can check it from protos, server code, or git history, and the item says which.

Items are grouped Resource model (R), Methods (M), Fields (F), Errors/auth/retries (E), Compatibility (C). The
full list, with links, is `skills/aip-audit/references/manual-review.md`.

**How the strengths were checked.** Version 0.1.0 wrote the checklist from memory. A claim-by-claim comparison
against the AIP sources on 2026-11-22 found that 25 of its 31 items were wrong, in one of three ways:

- the strength did not match the AIP. For example, AIP-155 makes `request_id` MAY, not SHOULD, and AIP-143 makes
  standard codes MUST, not SHOULD.
- a concrete detail was wrong. The RFC-1034 regex allowed a trailing hyphen. The etag-mismatch code was given as
  "`ABORTED` or `FAILED_PRECONDITION`", but AIP-154 says `ABORTED`. Soft delete used `expire_time` where AIP-164
  names `delete_time` and `purge_time`.
- the requirement was not in the cited AIP. AIP-194 says nothing about `request_id`, and AIP-180 does not mention
  `reserved`.

The current items were rewritten from the quoted AIP sentences. `tests/check_docs.py` runs in CI and checks that
the coverage map, Appendix A, and the item and rule counts in the docs agree with the checklist and with
`api-linter --list-rules`. The 25 errors were all in the hand-written layer. None
came from the linter.

### 3.3 Verdict model

| Verdict | Condition |
|---|---|
| CERTIFIED | 0 linter findings (justified disables allowed), all MUST and SHOULD items PASS or N/A (MAY → MUST items count as MUST when the feature is offered, N/A otherwise) |
| CERTIFIED WITH WARNINGS | 0 linter findings, no MUST item FAIL, and either a SHOULD FAIL or a MUST NOT VERIFIED |
| NOT CERTIFIED | any linter finding, any MUST FAIL, a breaking change in a stable version, or the linter was not run |

Every linter finding blocks, whatever its upstream category, for two reasons. The linter can already be scoped
with a config file, so any noise is the user's to silence explicitly. And a per-rule severity table would be a
second source of truth to keep in sync with upstream. The cost is that a single missing comment
(`core::0192::has-comments`) blocks certification. We accept that.

"NOT VERIFIED" exists so that a proto-only audit cannot claim server behaviour it never saw. Such an audit
reaches at most CERTIFIED WITH WARNINGS.

## 4. System Design

### 4.1 Integration

Each skill is a folder holding `SKILL.md` (YAML frontmatter plus Markdown instructions) and supporting files.
At startup a host reads only `name` and `description`, and it loads the body when a request matches. The
descriptions name the trigger phrases explicitly: *audit, review, lint, validate, certify, AIP compliance* for
`aip-audit`, and *create, design, scaffold, add a resource or method, extend* for `aip-design`. They are 582 and
536 characters, against the spec limit of 1024.

| File | When it is used | Lines |
|---|---|---|
| `aip-audit/SKILL.md` | loaded on trigger | ~110 |
| `aip-audit/references/manual-review.md` | read at step 3 of the audit | ~95 |
| `aip-audit/scripts/aip-lint.sh` | executed, never read into context | ~100 |
| `aip-design/SKILL.md` | loaded on trigger | ~70 |
| `aip-design/references/aip-cheatsheet.md` | read while writing | ~125 |
| `aip-design/assets/acme/library/v1/library.proto` | copied as a template | ~200 |

The repository is also a single-plugin Claude Code marketplace (`.claude-plugin/`). Other hosts ignore that folder.

### 4.2 Portability

The skills follow the Agent Skills specification. The folder name equals `name`, and the frontmatter uses only
`name`, `description`, `license` and `compatibility`. The body uses no host-specific variable (no
`${CLAUDE_PLUGIN_ROOT}`), tool name or slash command. Script paths are given relative to the `SKILL.md` folder,
and the agent is told to resolve them to absolute paths, whatever directory its host installed the skill in.

`aip-design` reaches the lint script through the sibling path `../aip-audit/scripts/aip-lint.sh`. Hosts install
skills as siblings in one directory (`~/.agents/skills/`, `~/.claude/skills/`, …), so this works as long as both
skills are installed. If `aip-audit` is missing, the skill tells the agent to report that rather than claim the
proto is lint-clean. We chose this over duplicating the script, which would let two copies drift apart.

The only runtime requirement is a shell tool that can run `bash`. Every listed host has one, though some ask for
approval on each command (§5.4).

Nothing in the instructions depends on the model. They are procedures and tables with no tuning for a particular
model, and the judgement they ask for (is this custom method justified?) is ordinary code review. How well each
model makes those calls has not been measured (§7).

### 4.3 Precedence

1. **Evidence over assertion.** No item is marked PASS without file:line evidence. Behaviour that the agent did not
   see is NOT VERIFIED, never PASS.
2. **The user's explicit scope and configuration.** Their `.api-linter.yaml`, the paths they chose, and inline
   disables that carry a reason.
3. **AIP guidance**, with the AIP's own MUST/SHOULD strength.

On fixes, compatibility outranks conformance. In a published version the agent does not rename, renumber or
retype anything to satisfy a rule (AIP-180). It adds and deprecates, or proposes a new major version (AIP-185).

### 4.4 Execution protocols

**aip-audit**

```
          ┌──────────────────────┐
request ─▶│ 1. Scope             │  proto root, published?, server code present?
          └──────────┬───────────┘
                     ▼
          ┌──────────────────────┐  exit 2 ─▶ fix setup; if impossible,
          │ 2. aip-lint.sh       │            verdict = NOT CERTIFIED
          │    (api-linter, buf) │
          └──────────┬───────────┘
                     ▼
          ┌──────────────────────┐
          │ 3. Manual checklist  │  38 items → PASS / FAIL / N/A / NOT VERIFIED
          │    (+ server code)   │  with file:line evidence
          └──────────┬───────────┘
                     ▼
          ┌──────────────────────┐
          │ 4. Verdict (§3.3)    │
          └──────────┬───────────┘
                     ▼
          ┌──────────────────────┐  only if asked; loop to 2 until clean
          │ 5. AIP-AUDIT.md      │──▶ 6. Fix
          └──────────────────────┘
```

**aip-design**

```
 request ─▶ 1. Resource model (nouns, parents, patterns, types, methods, LRO?)
              │   ambiguous domain ─▶ confirm with the user
              ▼
            2. Copy template, rename, delete unused methods
              ▼
            3. aip-lint.sh ──findings──▶ edit ──┐
              │ 0 findings                     │
              ▼                     ◀──────────┘
            4. Hand-off: what was built, what was left out, manual items still open
```

## 5. Tool Reference: `aip-lint.sh`

### 5.1 Synopsis

```
aip-lint.sh [-o FILE] [--strict] [--against REF] <proto_root> [file.proto ...]
```

| Argument | Meaning |
|---|---|
| `<proto_root>` | The directory that package paths are relative to. For `package acme.library.v1`, files live at `<proto_root>/acme/library/v1/`. The linter runs from this directory, so AIP-191 path rules work. |
| `file.proto …` | Optional, relative to the root. If omitted, every `*.proto` under the root, excluding any `google/`, `third_party/`, `node_modules/` or `vendor/` directory (vendored dependencies). |
| `-o FILE` | JSON report path. Default `$TMPDIR/aip-lint-report.json`. |
| `--strict` | Passes `--ignore-comment-disables`: inline `(-- api-linter: … --)` disables are ignored. |
| `--against REF` | Also runs `buf breaking --against REF` from the root. Local inputs (`.git…`, `./…`, `../…`) are resolved against the directory you run the script from, so when the root is a subdirectory you name it: `'.git#branch=main,subdir=proto'`, `'.git#tag=v1.2.0,subdir=proto'`. Remote inputs (`https://…git#…`, BSR modules) pass through unchanged. Needs `buf` and a `buf.yaml` in the root; without either the script exits 2 instead of skipping, so a requested comparison is never silently dropped. |

| Environment | Default | Meaning |
|---|---|---|
| `API_LINTER` | `api-linter` on `PATH`, then `$(go env GOPATH)/bin/api-linter` | Linter binary |
| `AIP_GOOGLEAPIS` | `~/.cache/aip-proto/googleapis` | Directory containing `google/api/annotations.proto`. If missing, it is filled once with `buf export buf.build/googleapis/googleapis`. |

| Exit | Meaning |
|---|---|
| 0 | no linter findings, and no breaking changes if `--against` was given |
| 1 | findings or breaking changes |
| 2 | setup error (linter, googleapis, buf or `buf.yaml` missing; bad root), compile error, or `buf breaking` failing for a reason other than breaking changes (for example a ref that does not exist). buf itself exits 100 for breaking changes; the script maps that to 1. |

stderr carries the summary table and one status line. stdout stays empty, so the script is safe to use in pipelines.

### 5.2 Configuration

The first of `.api-linter.yaml`, `api-linter.yaml`, `.api-linter.json`, `api-linter.json` found in the root is
passed as `--config`. The format is api-linter's own:

```yaml
- included_paths: ["**/*.proto"]
  disabled_rules: ["core::0192::has-comments"]
- included_paths: ["acme/legacy/**"]
  disabled_rules: ["core::0140::lower-snake"]
```

An inline disable, which the audit accepts only when it carries a reason:

```proto
// (-- api-linter: core::0140::lower-snake=disabled
//     aip.dev/not-precedent: wire name fixed by v1 clients. --)
int64 bookID = 1;
```

Measured on the fixture: 42 findings with no configuration; 27 with the first block of the config above (the
15 `has-comments` gone); 26 with the inline disable added; 27 again with `--strict`.

### 5.3 Report format

A JSON array with one entry per file:

```json
[{
  "file_path": "acme/library/v1/library.proto",
  "problems": [{
    "message": "Message `ListBooksRequest` has no `page_token` field.",
    "location": {
      "start_position": {"line_number": 47, "column_number": 1},
      "end_position":   {"line_number": 50, "column_number": 1},
      "path": "acme/library/v1/library.proto"
    },
    "rule_id": "core::0158::request-page-token-field",
    "rule_doc_uri": "https://linter.aip.dev/158/request-page-token-field"
  }]
}]
```

The AIP number is the second segment of `rule_id`. Some problems also carry a `suggestion`.

### 5.4 CI and hooks

GitHub Actions, on your API repository:

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-go@v5
  with: { go-version: stable }
- uses: bufbuild/buf-action@v1
  with: { setup_only: true }
- run: go install github.com/googleapis/api-linter/v2/cmd/api-linter@latest
- run: curl -fsSLO https://raw.githubusercontent.com/RustLangLatam/aip-proto/v0.2.0/skills/aip-audit/scripts/aip-lint.sh
- run: >-
    PATH="$PATH:$(go env GOPATH)/bin" bash aip-lint.sh -o aip.json
    --against "https://github.com/${{ github.repository }}.git#branch=main,subdir=proto" proto
```

GitLab CI:

```yaml
aip-lint:
  image: golang:1
  script:
    - go install github.com/googleapis/api-linter/v2/cmd/api-linter@latest
    - go install github.com/bufbuild/buf/cmd/buf@latest
    - bash tools/aip-lint.sh -o aip.json proto
  artifacts: { paths: [aip.json], when: always }
```

pre-commit, with the script vendored at `tools/aip-lint.sh`:

```yaml
repos:
  - repo: local
    hooks:
      - id: aip-lint
        name: AIP lint
        entry: bash tools/aip-lint.sh proto
        language: system
        files: \.proto$
        pass_filenames: false
```

Agent hosts that ask before each shell command will prompt for the script. Allow-listing `bash …/aip-lint.sh`
in the host's settings removes the prompt.

## 6. Expected Behaviour

What `tests/run.sh` checks (all rows run in CI):

| Input | Exit | Result |
|---|---|---|
| `aip-design/assets` (template) | 0 | 0 findings |
| `tests/fixtures/violations` | 1 | 42 findings, including `core::0126::unspecified`, `core::0131::synonyms`, `core::0142::time-field-names`, `core::0158::request-page-token-field`, `core::0140::lower-snake` |
| template under `proto/` in a git repo, `author` renumbered 3→7, `--against '.git#branch=main,subdir=proto'` | 1 | 0 lint findings, 1 breaking change: `Previously present field "3" with name "author" on message "Book" was deleted.` |
| same, `--against '.git#branch=nope'` | 2 | buf error, not reported as a finding |

With the skill active, an agent is expected to:

- run the linter rather than reason about rule-level details itself;
- report the resource-model gaps that the linter cannot see (R6 in the worked report);
- refuse to certify behaviour it has not seen (NOT VERIFIED);
- in design, settle the resource model before it writes any RPC.

These expectations come from the design. The last three depend on the agent following the instructions, and no
evaluation measures that yet (§8).

**Cost.** An audit loads about 200 lines of instructions and runs api-linter twice (JSON, then summary). On the
fixture the whole script finished in well under a second. The first run also downloads googleapis through
`buf export`. The manual pass is the expensive part: on a large API the agent reads every proto, and possibly the
server handlers. Scoping the audit to changed files keeps it bounded.

## 7. Threats to Validity

- **Coverage snapshot.** Appendix A reflects api-linter 2.4.1 and the AIP index as of 2026-11-22. Upstream adds
  rules, so an item that is manual today may gain a linter rule and the checklist would then repeat it. The
  checklist does not track upstream automatically.
- **Paraphrase.** Checklist items paraphrase AIPs, and a paraphrase can shift meaning or strength. Each item links
  its AIP, and the skill tells the agent to quote the AIP when it is in doubt.
- **Agent judgement.** Items such as M1 ("each custom method is justified") are judgement calls. Two runs, or two
  models, can disagree.
- **Static evidence of behaviour.** Reading handlers is not running them. A PASS on E2 means "the code paths that
  were read check authorization first", not "resources cannot be enumerated".
- **Strict verdict.** Making every linter finding blocking trades nuance for simplicity (§3.3).
- **Template bias.** Designs start from one CRUD template, which can nudge them toward CRUD where another shape
  fits better. The workflow puts the resource model before the template to limit this.

## 8. Future Work

- An evaluation set of protos with labelled defects of the kind the linter misses, scored per model and host.
- Machine-readable checklist output (JSON next to `AIP-AUDIT.md`) for dashboards.
- A diff-aware mode that audits only changed messages and services.
- Checklist items for AIP-153 (import/export) and AIP-236 (policy preview).

## References

- Google. *API Improvement Proposals — General AIPs.* https://google.aip.dev/general (accessed 2026-11-22).
- Google. *api-linter*, v2.4.1. https://github.com/googleapis/api-linter · rule documentation https://linter.aip.dev
- Buf Technologies. *Breaking change detection.* https://buf.build/docs/breaking/
- *Agent Skills specification.* https://agentskills.io/specification
- Bradner, S. (1997). *Key words for use in RFCs to Indicate Requirement Levels.* RFC 2119.

## Appendix A. AIP Coverage Index

`Rules` = api-linter 2.4.1 `core` rules for the AIP. `Items` = manual checklist items that link it. Order and
grouping follow google.aip.dev/general.

| Area | AIP | Title | Rules | Items |
|---|---|---|---|---|
| Meta | 1, 2, 3, 200, 8, 9 | Purpose, Numbering, Versioning, Precedent, Style, Glossary | — | — |
| Process | 100, 205 | Design review FAQ, Beta-blocking changes | — | — |
| Concepts | 111 | Planes | — | — |
| Resource design | 121 | Resource-oriented design | 3 | R1 |
| | 122 | Resource names | 7 | R6, R3, R3b, R4 |
| | 123 | Resource types | 17 | R6 |
| | 124 | Resource association | 1 | R4 |
| | 126 | Enumerations | 2 | — |
| | 128 | Declarative-friendly interfaces | 3 | — |
| | 129 | Server-modified values and defaults | 0 | F2 |
| | 156 | Singleton resources | 1 | R5 |
| | 236 | Policy preview | 0 | future work |
| Operations | 130 | Methods | 0 | — |
| | 131 | Get | 14 | — |
| | 132 | List | 17 | — |
| | 133 | Create | 20 | — |
| | 134 | Update | 16 | M4, F7 |
| | 135 | Delete | 15 | — |
| | 136 | Custom methods | 8 | M1 |
| | 151 | Long-running operations | 6 | M2 |
| | 231, 233, 234, 235 | Batch Get / Create / Update / Delete | 13, 13, 12, 14 | — |
| Fields | 140 | Field names | 8 | — |
| | 202 | Fields | 1 | — |
| | 203 | Field behavior | 4 | R2, F1, F1b |
| | 141 | Quantities | 2 | F3 |
| | 142 | Time and duration | 4 | F3b |
| | 143 | Standardized codes | 2 | F4 |
| | 144 | Repeated fields | 3 | — |
| | 145 | Ranges | 0 | — |
| | 146 | Generic fields | 1 | — |
| | 147 | Sensitive fields | 0 | F5 |
| | 148 | Standard fields | 6 | — |
| | 149 | Unset field values | 0 | F2b |
| | 216 | States | 4 | F7 |
| Design patterns | 152 | Jobs | 9 | — |
| | 153 | Import and export | 0 | future work |
| | 154 | Freshness validation | 3 | M5 |
| | 155 | Request identification | 1 | M3 |
| | 157 | Partial responses | 1 | — |
| | 158 | Pagination | 7 | M6, M6b, M6c |
| | 159 | Reading across collections | 1 | (mentioned in M10, R5) |
| | 160 | Filtering | 2 | M7 |
| | 161 | Field masks | 0 | — (see M4) |
| | 162 | Resource revisions (Draft) | 36 | — (warnings only) |
| | 163 | Change validation | 2 | M8 |
| | 164 | Soft delete | 11 | M9 |
| | 165 | Criteria-based delete | 15 | — |
| | 210 | Unicode | 0 | F6 |
| | 211 | Authorization checks | 0 | E2 |
| | 214 | Resource expiration | 2 | — |
| | 217 | Unreachable resources | 4 | M10 |
| Compatibility | 180 | Backwards compatibility | 0 (+ buf breaking) | R2, C1, C2, C2b |
| | 181 | Stability levels | 0 | — |
| | 182 | External dependencies (Reviewing) | 0 | — |
| | 184 | API version identifiers | 0 | — |
| | 185 | API versioning | 0 | C3, C4 |
| Polish | 190 | Naming conventions | 3 | — |
| | 191 | File and directory structure | 11 | — |
| | 192 | Documentation | 8 | — |
| | 193 | Errors | 0 | E1 |
| | 194 | Automatic retry | 0 | E3 |
| Protocol buffers | 127 | HTTP and gRPC transcoding | 5 | — |
| | 213 | Common components | 0 | C5 |
| | 215 | API-specific protos | 2 | C3, C5 |
