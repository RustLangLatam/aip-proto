# AIP audit: acme.library.v1 (test fixture) — NOT CERTIFIED

2026-11-22 · api-linter 2.4.1 · scope: `tests/fixtures/violations`, 1 file, proto only · strict: no
> Self-assessment against google.aip.dev. Not a Google certification.

*This is the report the `aip-audit` skill produces for the repository's negative fixture. The linter numbers come
from a real run of `aip-lint.sh`. It is here so you can see the output format before running it on your own API.*

## Summary

- **Linter:** 42 findings in 11 AIPs: 192 (15), 132 (5), 158 (4), 191 (4), 136 (3), 140 (3), 203 (3), 126 (2),
  131 (1), 142 (1), 216 (1).
- **Manual MUST failures:** R6, M6.
- **Manual SHOULD failures:** R1, M1, M6b, F3b, F7.
- **Not verified (no server code):** F1, E1, E2, E3.

Fix the resource model first. It is the main thing the linter misses (R6 below), and the method
findings depend on it. Do not expect the count to fall quickly. Renaming `FetchBook` to `GetBook` alone removes
the four AIP-131/136 findings, but it switches on the Get rules (`REQUIRED` name, `resource_reference`,
`method_signature`), so the total goes from 42 to 41 until those are done too.

## Blocking findings

| AIP | Rule / item | Location | Problem | Fix |
|---|---|---|---|---|
| 122/123 | R6 (manual) | `library.proto:32` | `Book` is returned by `FetchBook` and listed by `ListBooks`, so it is a resource, but it is identified by `int64 bookID` and has no `name` and no resource type. **The linter does not report this**, because it only treats messages that have `name` as resources. | Add `string name = 1 [IDENTIFIER]` and a `google.api.resource` with pattern `shelves/{shelf}/books/{book}`. Drop `bookID`. |
| 131 | `core::0131::synonyms` | `:12` | `FetchBook` is a Get under another name. | Rename to `GetBook(GetBookRequest{name})` → `Book`, `get: "/v1/{name=shelves/*/books/*}"`. |
| 136 | `request-message-name`, `response-message-name`, `http-uri-suffix` | `:12–13` | They follow from treating `FetchBook` as a custom method. | They disappear once it becomes `GetBook`. |
| 132 | `request-parent-required`, `request-unknown-fields` ×2, `response-unknown-fields` ×2 | `:47–54` | List has no `parent`, and it has `limit`, `offset`, `total`. | Add `parent` with `child_type`. Remove `limit`/`offset`/`total`. |
| 158 | `request-page-size-field`, `request-page-token-field`, `response-next-page-token-field`, `response-plural-first-field` | `:47–53` | Offset pagination. | `page_size`, `page_token` → `repeated Book books = 1; string next_page_token = 2;` |
| 158 | M6 (manual) | `:49` | `offset` is a cursor that clients can parse (MUST be opaque). | As above. |
| 140 | `lower-snake` ×2, `prepositions` | `:33, :34, :37` | `bookID`, `Title`, `modified_at`. | `name`, `title`, `update_time`. |
| 142 | `time-field-names` | `:37` | `modified_at`. | `google.protobuf.Timestamp update_time`. |
| 126 | `unspecified`, `upper-snake-values` | `:43–44` | No zero `UNSPECIFIED` value, and `archived` is lowercase. | `STATE_UNSPECIFIED = 0; ACTIVE = 1; ARCHIVED = 2;` |
| 216 | `synonyms` | `:42` | `Status` used for lifecycle. | Rename to `State`, nest it in `Book`, mark it `OUTPUT_ONLY`. |
| 203 | `field-behavior-required` ×3 | `:28, :48, :49` | No `field_behavior`. | Annotate every field. |
| 191 | `java-multiple-files`, `java-outer-classname`, `java-package`, `file-layout` | `:5, :42` | Language options missing, and the enum sits before messages. | Copy the options block from the template, and move the enum into `Book`. |
| 192 | `has-comments` ×15 | throughout | Undocumented service, messages and fields. | Add a leading comment to each. |

## Warnings

| AIP | Item | Location | Problem |
|---|---|---|---|
| 121 | R1 | `:10–25` | The service is RPC-style (`FetchBook`) rather than a resource hierarchy with standard methods. |
| 136 | M1 | `:12` | A custom method (`POST /v1/books/fetch`) is used where the standard Get fits. |
| 158 | M6b | `:47` | No default page size is documented. |
| 142 | F3b | `:36` | `int64 created` is a timestamp stored as an integer. **The linter does not report this**, because `created` lacks the `_time` suffix it looks for. Use `google.protobuf.Timestamp create_time [OUTPUT_ONLY]`. |
| 216 | F7 | `:39` | `status` can be written by clients. Lifecycle state should be `OUTPUT_ONLY` and changed through custom methods. (The `ACTIVE = 0` zero value is already reported by the linter under AIP-126.) |

## Justified disables

None.

## Manual checklist

| Item | Result | Evidence |
|---|---|---|
| R6 | FAIL | `Book` (`:32`) has `int64 bookID`, no `name`, no resource type |
| R1 | FAIL | `Library` exposes `FetchBook` (RPC style) |
| R2 | N/A | no resource names exist yet, and no method changes one (R6 covers the gap) |
| R3, R3b, R4, R5 | N/A | no user-set IDs, references or singletons |
| M1 | FAIL | `FetchBook` |
| M2, M4, M9, M10 | N/A | no long-running work, Update, soft delete or cross-collection reads |
| M3, M5, M7, M8 | N/A | optional features (`request_id`, `etag`, `filter`, `validate_only`) not offered |
| M6 | FAIL | `offset` (`:49`) |
| M6b | FAIL | no documented default page size |
| M6c | N/A | there is no `page_size` field |
| F1 | NOT VERIFIED | no server code; there are no annotations to check either |
| F1b, F2, F2b, F3, F4, F5, F6 | N/A | no immutable fields, server-owned values, optional primitives, unitless quantities, codes, secrets or length limits |
| F3b | FAIL | `int64 created` (`:36`) |
| F7 | FAIL | `status` writable (`:39`); the AIP-134 part is N/A because there is no Update |
| E1, E2, E3 | NOT VERIFIED | no server code in scope |
| C1, C2, C2b, C4 | N/A | unpublished API |
| C3 | PASS | `package acme.library.v1` |
| C5 | PASS | no API-specific common package |
