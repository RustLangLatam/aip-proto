# AIP cheatsheet for proto authors

A condensed reading of [google.aip.dev/general](https://google.aip.dev/general), checked against the AIP text on
2026-11-22. The AIP is authoritative. Follow its link when a case is not covered here. Strength words (must,
should, may) are the AIP's own.

## Resources ([121](https://google.aip.dev/121), [122](https://google.aip.dev/122), [123](https://google.aip.dev/123))

```proto
message Book {
  option (google.api.resource) = {
    type: "library.acme.com/Book"               // {Service Name}/{PascalCase singular}
    pattern: "publishers/{publisher}/books/{book}"
    singular: "book"                             // lowerCamelCase
    plural: "books"
  };
  string name = 1 [(google.api.field_behavior) = IDENTIFIER];
}
```

- Resources must expose a `string name` holding the resource name, and it should be the first field. `IDENTIFIER`
  must be attached to it (203).
- Collection IDs must be plural camelCase (`bookShelves`). Pattern variables must be snake_case singular.
- User-specified IDs: the format must be documented, and should match `^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$`.
- References to other resources: `string shelf = 3 [(google.api.resource_reference).type = "library.acme.com/Shelf"];`
  Parents in requests use `resource_reference.child_type`.

## Standard methods

Get is required for every resource (121, 131), and List is required unless the resource is a singleton (132). Create, Update
and Delete are provided when they make sense.

| Method | RPC | HTTP | Request fields | Returns |
|---|---|---|---|---|
| [Get 131](https://google.aip.dev/131) | `GetBook` | `get: "/v1/{name=publishers/*/books/*}"` | `name` (REQUIRED) | `Book` |
| [List 132](https://google.aip.dev/132) | `ListBooks` | `get: "/v1/{parent=publishers/*}/books"` | `parent`, `page_size`, `page_token`, opt. `filter`, `order_by`, `show_deleted` | `ListBooksResponse{repeated Book books = 1; string next_page_token = 2;}` |
| [Create 133](https://google.aip.dev/133) | `CreateBook` | `post: "/v1/{parent=…}/books" body: "book"` | `parent`, `book`, `book_id`, opt. `request_id`, `validate_only` | `Book` (or LRO) |
| [Update 134](https://google.aip.dev/134) | `UpdateBook` | `patch: "/v1/{book.name=…}" body: "book"` | `book`, `update_mask`, opt. `allow_missing`, `validate_only` | `Book` (or LRO) |
| [Delete 135](https://google.aip.dev/135) | `DeleteBook` | `delete: "/v1/{name=…}"` | `name`, opt. `etag`, `force`, `allow_missing` | `google.protobuf.Empty` (the resource, if soft delete) |
| [Custom 136](https://google.aip.dev/136) | `ArchiveBook` | `post: "/v1/{name=…}:archive" body: "*"` | `name` + args | `ArchiveBookResponse` (or the resource) |

One `method_signature` per standard method: Get/Delete `"name"`, List `"parent"`, Create `"parent,book,book_id"`,
Update `"book,update_mask"`.

Batch methods:

| Method | HTTP |
|---|---|
| [BatchGetBooks 231](https://google.aip.dev/231) | `get: "/v1/{parent=…}/books:batchGet"`, no body |
| [BatchCreateBooks 233](https://google.aip.dev/233), [BatchUpdateBooks 234](https://google.aip.dev/234), [BatchDeleteBooks 235](https://google.aip.dev/235) | `post: "/v1/{parent=…}/books:batchCreate"` (`:batchUpdate`, `:batchDelete`), `body: "*"` |

## Long-running operations ([151](https://google.aip.dev/151))

Methods that may take a significant amount of time (rule of thumb: 10 seconds) should return an `Operation`.
When they do, `operation_info` must name both types:

```proto
rpc ImportBooks(ImportBooksRequest) returns (google.longrunning.Operation) {
  option (google.api.http) = { post: "/v1/{parent=publishers/*}/books:import" body: "*" };
  option (google.longrunning.operation_info) = {
    response_type: "ImportBooksResponse"
    metadata_type: "ImportBooksMetadata"
  };
}
```

## Fields ([140](https://google.aip.dev/140)–[149](https://google.aip.dev/149), [203](https://google.aip.dev/203))

- Names are `lower_snake_case`, and repeated fields must be plural.
- Names should not include prepositions: `book_count`, not `number_of_books`. Counts use the `_count` suffix, not `num_`.
- Use well-known abbreviations such as `config`, `id`, `info`, `spec`, `stats`, and unit abbreviations (`km`, `px`).
- Booleans should omit `is_` (`archived`), except where the bare word is reserved (`is_new`).
- Time: `google.protobuf.Timestamp create_time / update_time / delete_time / expire_time` (should). Durations:
  `google.protobuf.Duration`, for example `ttl` or `timeout` (should). Integer timestamps only for compatibility,
  named with the unit (`send_time_millis`).
- Quantities whose type does not carry the unit must have it as a suffix: `size_bytes`, `distance_km` (141).
- `field_behavior` must be on every field of a resource or request message: `REQUIRED`, `OPTIONAL`, `OUTPUT_ONLY`,
  `INPUT_ONLY`, `IMMUTABLE`, `IDENTIFIER`, `UNORDERED_LIST`… There are two exceptions. The resource's `etag` gets
  none, and members of a `oneof` may omit it.
- Use `optional` on primitives if and only if "unset" must be told apart from the zero value (149).
- Standard fields ([148](https://google.aip.dev/148)): `name`, `parent`, `display_name`, `title`, `create_time`,
  `update_time`, `delete_time`, `expire_time`, `purge_time`, `annotations`, `uid` (OUTPUT_ONLY, UUID4). For `etag`
  see 154, and for `state` see 216.
- Enums ([126](https://google.aip.dev/126)): values must be `UPPER_SNAKE`. The first value should be
  `<ENUM>_UNSPECIFIED = 0`, unless a clearly useful zero value such as `UNKNOWN` exists. An enum used by only one
  message should be nested in it.
- States ([216](https://google.aip.dev/216)): `State state = N [OUTPUT_ONLY]`, changed through custom methods. A
  transition that is not allowed must fail with `FAILED_PRECONDITION`.

## Patterns

| Need | AIP | Shape |
|---|---|---|
| Pagination | [158](https://google.aip.dev/158) | `int32 page_size`, `string page_token` → `string next_page_token` (empty on the last page). Tokens must be opaque. If users need to skip results, use `int32 skip`. |
| Filtering / ordering | [160](https://google.aip.dev/160), [132](https://google.aip.dev/132) | `string filter` (AIP-160 grammar), `string order_by` (`"title desc, create_time"`) |
| Partial update | [134](https://google.aip.dev/134), [161](https://google.aip.dev/161) | `google.protobuf.FieldMask update_mask`. When omitted, it means all populated fields, and `*` means full replacement. |
| Partial response | [157](https://google.aip.dev/157) | a `View` enum field (`BASIC` / `FULL`), or the system field-mask parameter. A `read_mask` request field is deprecated. |
| Concurrency | [154](https://google.aip.dev/154) | `string etag` on the resource, with no `field_behavior`. Update reuses it; Delete and custom methods carry their own request `etag`. A mismatch must fail with `ABORTED`. |
| Idempotency | [155](https://google.aip.dev/155) | optional `string request_id`. UUIDs must be annotated `[(google.api.field_info).format = UUID4]`. When offered, it must guarantee idempotency. |
| Dry run | [163](https://google.aip.dev/163) | `bool validate_only`. It must run the same permission checks and validation as a live request. |
| Soft delete | [164](https://google.aip.dev/164) | Delete returns the resource; `UndeleteBook`; `delete_time`, `purge_time`; `bool show_deleted` on List |
| Read across parents | [159](https://google.aip.dev/159), [217](https://google.aip.dev/217) | the client sends `parent = "publishers/-"`, and the URI pattern keeps `*` (it must not hard-code `-`). If the read can partially fail, add `repeated string unreachable [UNORDERED_LIST]` to the response. |
| Expiry | [214](https://google.aip.dev/214) | `oneof expiration { Timestamp expire_time; Duration ttl [INPUT_ONLY]; }` |

## Errors ([193](https://google.aip.dev/193)), auth ([211](https://google.aip.dev/211))

Return `google.rpc.Status` with the canonical `google.rpc.Code`. Every error must include
`ErrorInfo{reason: "BOOK_LOCKED", domain: "library.acme.com"}`, where `reason` matches `[A-Z][A-Z0-9_]+[A-Z0-9]`,
up to 63 characters.

| Situation | Code |
|---|---|
| bad input | `INVALID_ARGUMENT` |
| missing / duplicate resource | `NOT_FOUND` / `ALREADY_EXISTS` |
| state transition not allowed | `FAILED_PRECONDITION` (216) |
| stale etag | `ABORTED` (154) |
| no permission | `PERMISSION_DENIED`, checked **before** any validation or existence check (211) |

## Files and versions ([191](https://google.aip.dev/191), [185](https://google.aip.dev/185), [180](https://google.aip.dev/180))

- `package acme.library.v1;` → file at `acme/library/v1/*.proto`. The major version goes at the end of the package
  and in the URI (`/v1/`). Alpha and beta add a suffix: `v1beta`.
- Published versions: only add. Never remove, rename, move between files, move into or out of a `oneof`, or retype a
  field in the same major version (180). A rename means adding the new field and deprecating the old one. Removing
  a field needs a new major version.
