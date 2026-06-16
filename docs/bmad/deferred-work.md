# Deferred Work

## Deferred from: code review of 1-1-validate-and-document-the-csv-domain-field-mapping (2026-06-16)

- **UTF-8 BOM on the fetched live CSV breaks `id` binding.** `BuildingPermitIngestor` reads the HTTP stream as UTF-8 without stripping a BOM; a leading `﻿` turns the first header into `﻿id`, so `@JsonProperty("id")` misses → `id` null → `externalId()` = `"null:<pub>"` and a poisoned dedup key. Pre-existing (`id` bound before this change). Fix: strip BOM in the reader / use a BOM-aware reader. Add a BOM fixture test.
- **No schema-drift / required-field validation.** Binding rests on exact-string match of 41 headers; a renamed column silently re-introduces null (the very bug this story fixed) and an added column is silently dropped (Jackson FAIL_ON_UNKNOWN off by default). Pre-existing. Fix: validate the header set / assert required fields (`id`, `publicationNumber`, `municipality_name`, `projectLocation_address_*`) on ingest, and/or a contract test that fails on header drift. (Relates to backlog B-01 follow-up.)
- **`externalId()` produces a malformed key when `id`/`publicationNumber` is missing.** `id + ":" + publicationNumber` yields `"null:…"`; the registry then registers a poisoned business key instead of the row being skipped/logged. Pre-existing. Fix: guard the business key (reject/log rows missing either part).
- **Real-header reader test under-asserts.** `shouldExposeRealOgdHeaderNamesAsPayloadKeys` checks only 4 of 10 headers and never asserts row/key completeness. Optional test hardening.

> Note: the related but distinct **coercion-aborts-the-batch** finding is tracked as a `[Review][Decision]` item in the story (it is a regression surface introduced by this change, pending a decision on fix-now vs. a dedicated ingestor-robustness story).
