---
name: aip-design
description: Design and write new protobuf / gRPC APIs (.proto) that follow Google's API Improvement Proposals (AIP, google.aip.dev/general) from the first line — resource-oriented design, resource names, standard methods (Get/List/Create/Update/Delete), field naming and behavior, pagination, long-running operations, errors, versioning. Starts from a lint-clean template and verifies the result with Google's api-linter. Use when the user asks to create, design, scaffold, add a resource or method to, or extend a .proto / gRPC / Google-style API.
license: MIT
compatibility: Needs a shell (bash), Google api-linter (go install github.com/googleapis/api-linter/v2/cmd/api-linter@latest) and buf or a local googleapis checkout. Works with any model; no host-specific tools.
---

# AIP design

Builds `.proto` APIs that pass [`api-linter`](https://linter.aip.dev) with zero findings and satisfy the AIPs
the linter cannot check. Rules in short: [references/aip-cheatsheet.md](references/aip-cheatsheet.md).
Template: [assets/acme/library/v1/library.proto](assets/acme/library/v1/library.proto) (lint-clean, CRUD for one resource).

## Workflow

### 1. Model resources before writing any RPC (AIP-121/122/123)

Write this down and confirm it with the user if the domain is ambiguous:

- the **resources** (nouns), their **parent** chain and **collection IDs** (plural, camelCase): `publishers/{publisher}/books/{book}`
- the resource **type**: `{Service Name}/{PascalCase singular}` → `library.acme.com/Book`
- which **standard methods** each resource gets. Get is required, and List is required unless the resource is a
  singleton (AIP-121, 132). Create, Update and Delete only where they make sense.
- which operations are **not** CRUD → custom methods `:verb` (AIP-136), only when no standard method fits
- which operations are **slow** → LRO (AIP-151)

### 2. Write the proto from the template

Copy the template, rename `acme.library.v1` / `Book` / `shelves`, delete the methods you do not need. Keep:

- package `<org>.<api>.<major version>` and a directory path that matches it (AIP-191, 185)
- the language options block (`java_package`, `csharp_namespace`, …), all consistent with each other (AIP-191)
- `google.api.resource` on every resource (AIP-123), and `string name` as the first field with `IDENTIFIER`
  (AIP-122, 203)
- `google.api.http` on every RPC (AIP-127), and one `method_signature` per standard method as AIP-131–135 show
- a `field_behavior` on every resource and request field, except the resource's `etag` (AIP-203, 154)
- a leading comment on every service, method, message, field and enum value (AIP-192)

### 3. Verify

The lint script ships with the sibling skill `aip-audit`: `../aip-audit/scripts/aip-lint.sh`, relative to the
folder of this `SKILL.md`. Resolve it to an absolute path and run:

```bash
bash <skills-dir>/aip-audit/scripts/aip-lint.sh <proto_root>
```

If `aip-audit` is not installed next to this skill, tell the user to install it, and do not claim the proto is lint-clean.

Iterate until there are **0 findings**. Do not suppress a rule to get there. If a disable is genuinely right,
add `// (-- api-linter: <rule>=disabled --)` with a reason, and tell the user.

### 4. Hand-off

Tell the user what was produced, which methods were deliberately left out and why, and the manual items still
open (for example "server must implement update_mask semantics", AIP-134). The `aip-audit` skill gives a
formal verdict.

## Don'ts

- No `int64 id` as identity. Use `string name` with a resource pattern.
- No `limit`/`offset`. Use `page_size`/`page_token`/`next_page_token`, plus `int32 skip` if users must skip results (AIP-158).
- No `created_at` / Unix ints. Use `google.protobuf.Timestamp create_time` (AIP-142). Integers only when an
  external spec forces them, named with the unit (`send_time_millis`).
- No enum whose zero value means something real. Start with `<ENUM>_UNSPECIFIED = 0`, unless a useful zero
  value such as `UNKNOWN` exists (AIP-126).
- No `Status` / `Result` / `Data` wrappers. Get, Create and Update return the resource itself, or an LRO that resolves to it (AIP-131, 133, 134).
- No breaking edits to a published version (AIP-180): no removing, renaming, retyping or moving. Add fields and
  methods instead, and deprecate the old ones.
