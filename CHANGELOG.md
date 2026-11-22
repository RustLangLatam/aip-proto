# Changelog

## 0.2.0 — 2026-11-22

Restructured for public, multi-client use, following the layout of storyscope-rules.

- Skills are client-neutral: script paths are relative to each `SKILL.md` instead of a plugin root, and the
  frontmatter adds `license` and `compatibility`. The README documents install paths for Claude Code, Codex,
  Gemini CLI, Cursor, Copilot and OpenCode. Only Claude Code was exercised in this release.
- New `NOT VERIFIED` result for behavioural items when there is no server code. A proto-only audit now reaches
  at most CERTIFIED WITH WARNINGS.
- `aip-audit` now tells the agent about a linter blind spot: messages without `name` are not seen as resources.
- Coverage map corrected: AIPs 130, 131, 132, 133, 135, 145, 153, 182, 184 and 236 were marked as having
  checklist items they did not have.
- Linter counts corrected from "~330 rules / 50 AIPs" to the measured 340 rules / 46 AIPs.
- Added `docs/TECHNICAL_REPORT.md`, `docs/examples/AIP-AUDIT.fixture.md` and `CITATION.cff`.

Semantic review against the AIP sources (fetched 2026-11-22) and against the tools' real behaviour:

- **Checklist rewritten.** 25 of the 31 items in 0.1.0 had a wrong strength, a wrong detail, or a requirement
  that is not in the cited AIP. Examples: ABORTED is the only etag-mismatch code (AIP-154); `request_id`,
  `validate_only`, `etag` and `filter` are MAY, not SHOULD; AIP-143 codes are MUST; soft delete uses
  `delete_time`/`purge_time`; AIP-194 says nothing about `request_id`. Mixed requirements are split, and the
  checklist now has 38 items over 31 AIPs. A new **MAY → MUST** strength covers optional features.
- **New R6 (MUST)** for resources without `string name` and a resource type. This is the linter's main blind
  spot, and it was filed under R1/R2 before.
- **Template:** the `book_id` regex allowed a trailing hyphen, and it is now AIP-122's
  `^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$`. `Book.etag` no longer has a `field_behavior` (AIP-154, AIP-203).
- **Cheatsheet:** BatchGet is GET with no body (AIP-231; the linter confirms). `read_mask` request fields are
  deprecated (AIP-157). The AIP-148 standard-field list is corrected, and `labels`, `etag` and `state` are not
  148. The advice to mark deleted fields `reserved` is gone, because AIP-180 forbids removing them. Enum and
  boolean rules use the AIP's own "should".
- **aip-lint.sh:** `--against` with a relative `.git` input broke when `<proto_root>` was a subdirectory, and
  that buf failure was reported as "breaking changes" (exit 1). Now local inputs resolve from the caller's
  directory, buf errors exit 2, and a missing `buf` or `buf.yaml` is an error instead of a silent skip. Nested
  `google/` directories are excluded too.
- **Worked report:** "renaming to GetBook clears 4 findings" was misleading. The real count goes from 42 to 41,
  because the Get rules switch on.
- **README:** removed unsupported claims about which clients prompt before shell commands.
- **Tests:** `tests/run.sh` now covers the `--against` exit codes, and `tests/check_docs.py` keeps the coverage
  map, Appendix A and the counts in sync with the checklist and `api-linter --list-rules`.

## 0.1.0 — 2026-11-22

- `aip-audit` skill: api-linter pass + manual checklist of 31 non-lintable items + certification verdict.
- `aip-design` skill: resource-first workflow, lint-clean template, AIP cheatsheet.
- `aip-lint.sh`: api-linter wrapper with automatic googleapis fetch, `--strict`, `--against` (buf breaking).
- Self-test and CI against api-linter 2.4.1.
