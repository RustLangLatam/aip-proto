---
name: aip-audit
description: Audit and certify existing protobuf / gRPC API definitions (.proto) against Google's API Improvement Proposals (AIP, google.aip.dev/general). Runs Google's official api-linter, then a manual review of the AIPs no linter can check (errors, compatibility, versioning, authorization, idempotency, LRO choice), and issues a CERTIFIED / CERTIFIED WITH WARNINGS / NOT CERTIFIED verdict with every finding cited by AIP number. Use when the user asks to audit, review, lint, validate, certify or check AIP compliance of .proto files, a gRPC API, a Google-style API, or a proto pull request.
license: MIT
compatibility: Needs a shell (bash), Google api-linter (go install github.com/googleapis/api-linter/v2/cmd/api-linter@latest) and buf or a local googleapis checkout. Works with any model; no host-specific tools.
---

# AIP audit

Certifies `.proto` APIs against [google.aip.dev/general](https://google.aip.dev/general).
Two layers, always both:

1. **Automated**: Google's own [`api-linter`](https://linter.aip.dev) (340 rules over 46 AIPs in v2.4.1).
   Never re-implement its rules by reading the proto; run it.
2. **Manual**: the AIPs the linter cannot see (semantics, behaviour, process).
   Checklist in [references/manual-review.md](references/manual-review.md).

This is self-assessment against public guidance. It is **not** a Google certification;
say so in the report.

## Workflow

### 1. Scope

- Find the proto root: the directory whose subpaths match the `package` (for example `acme/library/v1/x.proto`
  for `package acme.library.v1`). Look for `buf.yaml`, `proto/`, `api/`. Ignore vendored `google/`,
  `third_party/`.
- Ask only if there are several unrelated roots and the user named none.
- Note whether the API is new or already published (published means compatibility rules apply, AIP-180).

### 2. Automated pass

`scripts/aip-lint.sh` is in the same folder as this `SKILL.md`. Resolve that folder to an absolute path
(wherever your client installed the skill) and run:

```bash
bash <skill-folder>/scripts/aip-lint.sh -o <tmp>/aip-report.json <proto_root>
# add --strict to ignore (-- api-linter: rule=disabled --) comments
# add --against '.git#branch=main,subdir=<proto_root>' to also run buf breaking
#   (needs buf and a buf.yaml in <proto_root>; drop ,subdir= if the root is the repo root)
```

Exit 0 = clean, 1 = findings, 2 = setup/compile error. On exit 2, fix the setup (the script prints the
install command) instead of falling back to reading the proto by eye. If installing is impossible, say the
automated layer was **not run** and the verdict cannot be better than NOT CERTIFIED.

Read the JSON: each problem has `rule_id` (`core::0158::request-page-token-field`), `rule_doc_uri`,
`message`, `location`. Group by AIP number.

Disabled rules: grep for `api-linter:` comments and the linter config. Each disable is acceptable only with
a written reason next to it; list them in the report.

### 3. Manual pass

Walk [references/manual-review.md](references/manual-review.md) item by item against the protos (and the server code,
if it is in the repo and the item concerns behaviour, such as errors or authorization). For each item, record
PASS / FAIL / N/A / NOT VERIFIED, with file:line evidence. Do not mark PASS without having looked.
Use NOT VERIFIED for the items that describe what the server does (M3–M6c, M8, M10, F1, F1b, F6, F7, E1–E3)
when you cannot read the server code. N/A means the item does not apply, for example soft-delete checks on an
API that has no Delete method. A **MAY → MUST** item is N/A when the API does not offer the feature, and is
checked as MUST when it does.

The linter only recognises a message as a resource if it has a `name` field. When a message is clearly a
resource but has no `name` (for example `int64 id`), the linter reports nothing about it. Report that under
R6 yourself.

### 4. Verdict

| Verdict | Condition |
|---|---|
| **CERTIFIED** | 0 linter findings (justified disables allowed), every MUST item PASS or N/A, every SHOULD item PASS or N/A |
| **CERTIFIED WITH WARNINGS** | 0 linter findings, every MUST item PASS, N/A or NOT VERIFIED, and either a SHOULD item FAIL or a MUST item NOT VERIFIED |
| **NOT CERTIFIED** | any linter finding, any MUST item FAIL, a breaking change in a stable version, or the automated pass was not run |

A proto-only audit, with no server code, can therefore reach CERTIFIED WITH WARNINGS at most. Say this in the
summary, as "scope: proto only".

### 5. Report

Write `AIP-AUDIT.md` (or print it if the user asked for chat only):

```markdown
# AIP audit: <api name> — <VERDICT>
Date · api-linter <version> · scope: <root>, <n> files · strict: yes/no
> Self-assessment against google.aip.dev. Not a Google certification.

## Summary
<linter findings by AIP> · <manual MUST fails> · <SHOULD fails>

## Blocking findings
| AIP | Rule / item | Location | Problem | Fix |

## Warnings
| … |

## Justified disables
| Rule | Location | Reason given |

## Manual checklist
<item → PASS/FAIL/N/A + evidence>
```

Order the findings by impact: resource model (AIP-121/122/123) first, because fixing it usually clears
dozens of method-level findings, then methods, fields, polish.

### 6. Fixing (only if asked)

Apply fixes, then re-run step 2 until it is clean. For a **published** API, never fix by renaming,
renumbering or retyping fields or methods. That is a breaking change (AIP-180). Add new fields or methods,
deprecate old ones, or plan a new major version (AIP-185).

To build a new API correctly from the start, use the `aip-design` skill.
