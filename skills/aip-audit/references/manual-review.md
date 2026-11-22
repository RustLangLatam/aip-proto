# Manual review checklist

What `api-linter` cannot check. Each item names its AIP and the strength the AIP itself uses (RFC 2119):

- **MUST** items block certification.
- **SHOULD** items produce warnings.
- **MAY → MUST** items describe an optional feature. If the API does not offer the feature, the item is N/A.
  If it does, the MUST part is checked as a MUST.

Strengths were checked against the AIP text on 2026-11-22. If an AIP reads differently today, the AIP wins. Open it
and quote it in the finding.

## Resource model

| # | AIP | Strength | Check |
|---|---|---|---|
| R6 | [122](https://google.aip.dev/122), [123](https://google.aip.dev/123) | MUST | Every resource has its resource name in a `string` field called `name`, and has a resource type (`{Service Name}/{Type}`). **The linter only recognises resources that already have `name`**, so look for messages that are clearly resources (they carry an ID, or Get/List/Create return them). Identifying them by `int64 id` fails this item. |
| R1 | [121](https://google.aip.dev/121) | SHOULD | The API is modelled as a resource hierarchy (nouns) and prefers standard methods. Custom methods are used only where no standard method fits. Get/List support per resource is linted (`core::0121`). |
| R2 | [180](https://google.aip.dev/180), [203](https://google.aip.dev/203) | MUST | A resource never changes its name, so no method renames or moves resources by changing `name`. `name` is annotated `IDENTIFIER`, which implies immutable. |
| R3 | [122](https://google.aip.dev/122) | MUST | If resource IDs are user-specified, their allowed format is documented (for example on the `<resource>_id` field of Create). |
| R3b | [122](https://google.aip.dev/122) | SHOULD | User-specified IDs conform to RFC-1034: `^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$`. |
| R4 | [122](https://google.aip.dev/122), [124](https://google.aip.dev/124) | SHOULD | A field that refers to another resource is a `string` holding its resource name, with `google.api.resource_reference`. It is not an embedded copy or a numeric ID. Many-to-many associations are `repeated string` (AIP-124). |
| R5 | [156](https://google.aip.dev/156) | MUST | Singletons define no Create or Delete method. If they define List, it follows AIP-159. |

## Methods and behaviour

| # | AIP | Strength | Check |
|---|---|---|---|
| M1 | [136](https://google.aip.dev/136) | SHOULD | Each custom method covers functionality that cannot easily be expressed with a standard method. |
| M2 | [151](https://google.aip.dev/151) | SHOULD | Methods that can take a significant amount of time (the AIP's rule of thumb is 10 seconds) return `google.longrunning.Operation`. The `operation_info` annotation itself is linted. |
| M3 | [155](https://google.aip.dev/155) | MAY → MUST | A `request_id` field is optional. If it is offered, the server deduplicates on it, because providing a request ID must guarantee idempotency. It SHOULD accept UUIDs. |
| M4 | [134](https://google.aip.dev/134) | MUST | Update: an omitted `update_mask` is treated as "all populated fields", the special mask `*` means full replacement and is supported, and the server code does this. |
| M5 | [154](https://google.aip.dev/154) | MAY → MUST | `etag` is optional (it is required for declarative-friendly resources). If it is offered, a request carrying a stale etag fails with `ABORTED`, unless another error such as `PERMISSION_DENIED` takes precedence. |
| M6 | [158](https://google.aip.dev/158) | MUST | Page tokens are opaque, URL-safe strings that users cannot parse. A raw offset fails this, and so does a merely base64-encoded offset. |
| M6b | [158](https://google.aip.dev/158) | SHOULD | The default `page_size` is documented, and values above the maximum are coerced down rather than rejected. |
| M6c | [158](https://google.aip.dev/158) | MUST | A negative `page_size` returns `INVALID_ARGUMENT`. |
| M7 | [160](https://google.aip.dev/160) | MAY → MUST | Filtering is optional. If `filter` exists, it SHOULD follow the AIP-160 grammar, and the API MUST document the fields that bare literals match, any functions, and any deviations from the grammar. |
| M8 | [163](https://google.aip.dev/163) | MAY → MUST | `validate_only` is optional (it is required on declarative-friendly mutations). If it is offered, a validate-only request performs the same permission checks and validation as a live request. |
| M9 | [164](https://google.aip.dev/164) | SHOULD | If soft delete is offered, it comes with an `Undelete` method and `delete_time` and `purge_time` fields. Soft-deleted resources are hidden from List unless `show_deleted` is true, and the time until they are purged is documented. |
| M10 | [217](https://google.aip.dev/217) | MUST | A read method that can partially fail because some resources are temporarily unreachable (for example a `-` wildcard read, AIP-159) says so in the response (`unreachable`), instead of returning partial data silently. |

## Fields

| # | AIP | Strength | Check |
|---|---|---|---|
| F1 | [203](https://google.aip.dev/203) | MUST | The annotations are true. A `REQUIRED` field must really be present and non-empty, and the server does not accept requests without it. A value sent in an `OUTPUT_ONLY` field is cleared by the server, never rejected with an error. |
| F1b | [203](https://google.aip.dev/203) | SHOULD | An `IMMUTABLE` field sent with its current value is ignored. A request that tries to change it fails with `INVALID_ARGUMENT`. |
| F2 | [129](https://google.aip.dev/129) | MUST | Each field has a single owner. When the server picks or normalises a value that users can also set, the server's value goes in a separate `OUTPUT_ONLY` field (an "effective" value), not over the user's field. |
| F2b | [149](https://google.aip.dev/149) | SHOULD | `optional` is used on primitives if and only if "unset" must be told apart from the zero value. |
| F3 | [141](https://google.aip.dev/141) | MUST | Quantities whose type does not carry a unit (bytes, miles…) have the unit as a suffix: `size_bytes`, `distance_miles`. |
| F3b | [142](https://google.aip.dev/142) | SHOULD | Points in time are `google.protobuf.Timestamp` named `*_time`, and spans of time are `google.protobuf.Duration`. The linter flags this only for fields already named `_time`, so look for `int64 created`, `string date` and the like. |
| F4 | [143](https://google.aip.dev/143) | MUST | Standard codes with standard names: BCP-47 in `language_code`, Unicode CLDR region codes in `region_code`, ISO-4217 in `currency_code`. |
| F5 | [147](https://google.aip.dev/147) | SHOULD | Secrets and credentials are accepted as `INPUT_ONLY` fields and never returned. When clients need to know whether one is set, there is an `OUTPUT_ONLY` `<field>_set` boolean. |
| F6 | [210](https://google.aip.dev/210) | MUST | String length limits are measured and enforced in characters (code points), not bytes. Unique identifiers that allow non-ASCII reject input that is not in Normalization Form C. |
| F7 | [216](https://google.aip.dev/216), [134](https://google.aip.dev/134) | SHOULD / MUST | Lifecycle `state` behaves and is documented as output only, and transitions happen through custom methods (216, SHOULD). Update methods never write state fields directly (134, MUST). |

## Errors, auth, retries

| # | AIP | Strength | Check |
|---|---|---|---|
| E1 | [193](https://google.aip.dev/193) | MUST | Errors are `google.rpc.Status` with the canonical `google.rpc.Code` that fits, not everything `INTERNAL`/`UNKNOWN`. Every error includes a `google.rpc.ErrorInfo` whose `reason` matches `[A-Z][A-Z0-9_]+[A-Z0-9]` (at most 63 characters) and has a `domain`. |
| E2 | [211](https://google.aip.dev/211) | MUST | Authorization is checked before any request validation. A caller without permission gets `PERMISSION_DENIED` whether or not the resource exists, so existence is never leaked. |
| E3 | [194](https://google.aip.dev/194) | SHOULD | Automatic client retries (retry config, interceptors) are limited to unary, non-transactional requests that are safe to repeat, and to `UNAVAILABLE`. Transactional and state-changing requests are not retried automatically. |

## Compatibility and versioning (published APIs)

| # | AIP | Strength | Check |
|---|---|---|---|
| C1 | [180](https://google.aip.dev/180) | MUST | Within a major version, no component is removed or renamed (a rename counts as remove-and-add), no field changes type, no field moves into or out of a `oneof`, and nothing moves between files. Run `aip-lint.sh --against`. `buf breaking` also catches reused field numbers, which is protobuf practice rather than AIP text. |
| C2 | [180](https://google.aip.dev/180) | MUST | No new required fields, no changed default values, and no change in visible behaviour or semantics that is likely to break clients. |
| C2b | [180](https://google.aip.dev/180) | SHOULD | The valid format of resource names, and the upper bounds on string lengths, are not tightened. |
| C3 | [185](https://google.aip.dev/185), [215](https://google.aip.dev/215) | MUST | The major version is the last component of the package (`v1`, `v1beta`), and packages carry no minor or patch versions. |
| C4 | [185](https://google.aip.dev/185) | MUST | Alpha and beta channels carry their stability level in the version (`v1alpha`, `v1beta`), and stable versions carry none. Deprecated functionality does not graduate to a more stable channel. Marking elements `deprecated = true` is allowed (MAY). |
| C5 | [215](https://google.aip.dev/215), [213](https://google.aip.dev/213) | MUST | The API does not create its own "API-specific common component" packages (215). It may import the global common components (`google.type.*` and the others listed in AIP-213). |

## AIP coverage map

Which layer covers each AIP listed on google.aip.dev/general.
**L** = api-linter rules exist, **M** = manual item above, **—** = no rule and no item. For uncovered AIPs, use
reviewer judgement and report findings as warnings.

| Area | AIPs |
|---|---|
| Meta / process | 1 —, 2 —, 3 —, 8 —, 9 —, 100 —, 200 —, 205 — (not applicable to code) |
| Concepts | 111 — (planes: note in report if a management/data plane split exists) |
| Resource design | 121 L+M, 122 L+M, 123 L+M, 124 L+M, 126 L, 128 L, 129 M, 156 L+M, 236 — (policy preview) |
| Operations | 130 —, 131–133 L, 134 L+M, 135 L, 136 L+M, 151 L+M, 231/233/234/235 L |
| Fields | 140 L, 202 L, 203 L+M, 141 L+M, 142 L+M, 143 L+M, 144 L, 145 —, 146 L, 147 M, 148 L, 149 M, 216 L+M |
| Design patterns | 152 L, 153 —, 154 L+M, 155 L+M, 157 L, 158 L+M, 159 L, 160 L+M, 161 — (see M4), 162 L, 163 L+M, 164 L+M, 165 L, 210 M, 211 M, 214 L, 217 L+M |
| Compatibility | 180 M (+buf breaking), 181 —, 182 —, 184 —, 185 M |
| Polish | 190 L, 191 L, 192 L, 193 M, 194 M |
| Protocol buffers | 127 L, 213 M, 215 L+M |

AIP-162 (revisions) is Draft and AIP-182 is Reviewing. Report findings on them as warnings, never as blockers.
