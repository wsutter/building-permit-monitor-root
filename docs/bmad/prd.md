# Product Requirements Document — Building Permit Monitor

> BMAD planning artifact · Author: Walter Sutter · Date: 2026-06-12 · Status: draft
> Derived from `project-brief.md` and grounded in the current implementation. Requirements marked **(planned)** are not yet implemented.

## 1. Overview

Building Permit Monitor turns periodic open building-permit data for the Canton of Zurich into a continuously updated, geocoded, spatially queryable dataset, delivered through an event-driven pipeline and a REST API. This PRD defines the product requirements for the MVP and the immediate next increments.

## 2. Objectives & Success Metrics

| Objective | Metric | MVP target |
|-----------|--------|------------|
| Reliable ingestion | Scheduled import succeeds without manual intervention | Cron-driven poll completes; new permits emitted |
| No duplicate processing | Re-import of unchanged data emits 0 new raw events | Duplicates skipped via registry |
| Clean domain model | Normalized events carry canonical category & status enums | 100% of normalized events use `BuildingPermitCategory` / `BuildingPermitStatus` vocab |
| Accurate geocoding | Permits with a usable address get WGS84 coordinates | Address-level hits geocoded; failures marked `NOT_FOUND`, not faked |
| Spatial queryability | Radius / bounding-box queries return correct results | PostGIS `ST_DWithin` / `ST_MakeEnvelope` queries operational |
| Queryable API | `GET /api/building-permits` returns filtered results < reasonable latency | Filter by municipality & category, capped at 500 rows |
| Fault isolation | A poison message never blocks the pipeline | Failed messages land in the correct DLQ |

## 3. Personas

- **P1 — Platform owner / developer (Walter):** runs the stack locally, extends services, presents each as a portfolio repo.
- **P2 — API consumer (Studio r2 web app / external client):** queries permits by area and attributes to render maps and lists.
- **P3 — Reviewer:** reads an individual service repo and expects it to build, test, and run standalone.

## 4. Functional Requirements

### Epic A — Ingestion (`ingestor`)
- **FR-A1** Periodically (cron) download the Canton ZH building-permit CSV from the configured `source-url`.
- **FR-A2** Parse each CSV record into a `BuildingPermitRawEvent` (flat Canton-ZH schema).
- **FR-A3** Compute a stable business key `externalId = id + ":" + publicationNumber`.
- **FR-A4** Skip permits already seen: consult the raw-event registry; only publish new permits.
- **FR-A5** Publish new raw events to `building-permit.raw`, keyed by external id.
- **FR-A6** Prune blank/null payload fields before publishing.

### Epic B — Normalization (`normalizer`)
- **FR-B1** Consume `building-permit.raw` under consumer group `normalizer`.
- **FR-B2** Map the raw Canton-ZH record into `BuildingPermitNormalizedEvent` (stable internal schema).
- **FR-B3** Classify into a canonical `BuildingPermitCategory` (NEW_BUILDING, RENOVATION, DEMOLITION, REFURBISHMENT, OTHER, UNKNOWN).
- **FR-B4** Normalize status into `BuildingPermitStatus` (SUBMITTED, APPROVED, REJECTED, WITHDRAWN, UNKNOWN).
- **FR-B5** Compose a human-usable `address` (street + number, ZIP + town) and carry `municipality`.
- **FR-B6** Publish to `building-permit.normalized`, keyed by `permitId`.
- **FR-B7** Route failures to `building-permit.raw.dlq`.

### Epic C — Enrichment (`enricher`)
- **FR-C1** Consume `building-permit.normalized` under consumer group `enricher`.
- **FR-C2** Geocode the address via the GeoAdmin Search API (`api3.geo.admin.ch`), using municipality as context.
- **FR-C3** Return WGS84 (EPSG:4326) latitude/longitude.
- **FR-C4** Set `geocodingProvider` (GEO_ADMIN) and `geocodingQuality` (ADDRESS / PARCEL / MUNICIPALITY / NOT_FOUND).
- **FR-C5** Apply a fallback strategy: full address → reduced address → town; no marker if nothing reliable is found (never fabricate coordinates).
- **FR-C6** Publish to `building-permit.enriched`, keyed by `permitId`.
- **FR-C7** Route failures to `building-permit.normalized.dlq`.

### Epic D — Persistence (`persistence`)
- **FR-D1** Consume `building-permit.enriched` under consumer group `persistence`.
- **FR-D2** Upsert into `building_permits` keyed on `(source, external_id)`; deterministic `id = nameUUIDFromBytes(permitId)`.
- **FR-D3** Store a PostGIS `geom GEOMETRY(Point,4326)` only when both coordinates exist; store lat/lon and geocoding metadata.
- **FR-D4** Store the full enriched event as `raw_payload` JSONB.
- **FR-D5** Manage schema via Flyway migrations applied on startup.
- **FR-D6** Maintain the raw-event registry table used for duplicate detection (FR-A4).
- **FR-D7** Support spatial queries: within-radius (`ST_DWithin`) and bounding-box (`ST_MakeEnvelope && geom`).
- **FR-D8** Route failures to `building-permit.enriched.dlq`.
- **FR-D9** Maintain `updated_at` on upsert (set to now() on modification; `created_at` unchanged). *(backlog B-07)*

### Epic E — Query API (`api`)
- **FR-E1** Expose `GET /api/building-permits` returning `BuildingPermitDto` records.
- **FR-E2** Optional filters `municipality` and `category`, applied via parameterized SQL (`NamedParameterJdbcTemplate`).
- **FR-E3** Order by `published_date DESC NULLS LAST`, cap result set at 500.
- **FR-E4 (planned)** Bounding-box filter for map viewports (expose persistence `findVisiblePermits`). *(backlog B-03)*
- **FR-E5 (planned)** Radius filter around a point (expose persistence `findWithinRadius`). *(backlog B-04)*
- **FR-E6 (planned)** Date-range and free-text filters; streaming endpoints (SSE/WebFlux).

### Epic F — Platform & Contracts (`platform`, `contracts`)
- **FR-F1** Provide local infrastructure (Kafka KRaft, PostGIS, Conduktor Console) via Podman Compose.
- **FR-F2** Create the six topics (3 main + 3 DLQ), 1 partition, RF 1, 7-day retention.
- **FR-F3** Centralize event classes, topic names, consumer-group ids, and DLQ error handling in `contracts`.

### Epic G — Web map (planned)
- **FR-G1 (planned)** Reusable Angular 19+ library with Leaflet map, markers, filters, and detail popups, integrable as an npm dependency into the Studio r2 web app.

## 5. Non-Functional Requirements

- **NFR-1 Modularity:** every service builds, tests, and runs standalone; shared contracts live only in `contracts`.
- **NFR-2 Loose coupling:** services integrate through Kafka events, not synchronous REST calls (exception: ingestor consults the persistence registry for dedup).
- **NFR-3 Idempotency:** re-processing the same permit must not create duplicates (registry + `(source, external_id)` upsert).
- **NFR-4 Fault isolation:** poison messages go to DLQs (3 retries, 1 s fixed backoff) and never halt the consumer.
- **NFR-5 Observability:** Spring Boot Actuator (`health`, `info`, `metrics`) exposed; consistent SLF4J→Log4j2 logging.
- **NFR-6 Coordinate correctness:** lat/lon are human-readable in events/DTOs; PostGIS receives `(longitude, latitude)`. See `architecture.md`.
- **NFR-7 Reproducible builds:** central parent POM pins Java/Spring/plugin versions; Spotless-enforced formatting; JaCoCo coverage.
- **NFR-8 Quality:** each service has at least a Spring context smoke test; PostGIS repository tests use Testcontainers.

## 6. Data Contracts (authoritative shapes)

- `BuildingPermitRawEvent` — flat Canton-ZH schema; exposes `externalId()`.
- `BuildingPermitNormalizedEvent` — `permitId, source, externalId, title, description, category, status, municipality, publishedDate, address`.
- `BuildingPermitEnrichedEvent` — normalized fields + `latitude, longitude, geocodingProvider, geocodingQuality`.

See `specs/contracts.md` for field-level detail.

## 7. Acceptance Criteria (MVP, Given/When/Then)

- **AC-1 (FR-A4/D6):** *Given* a permit already in the registry, *when* the ingestor re-reads the CSV, *then* no new raw event is published and a skip is logged.
- **AC-2 (FR-B3/B4):** *Given* a raw event, *when* normalized, *then* its `category` and `status` are members of the canonical enums (`UNKNOWN` when undecidable).
- **AC-3 (FR-C5):** *Given* an address that cannot be geocoded, *when* enriched, *then* coordinates are null and `geocodingQuality = NOT_FOUND` (no fabricated point).
- **AC-4 (FR-D2/D3):** *Given* an enriched event with both coordinates, *when* persisted, *then* a row exists keyed by `(source, external_id)` with a non-null `geom` of SRID 4326; re-delivery updates the same row.
- **AC-5 (FR-D7):** *Given* persisted permits, *when* a radius query runs, *then* only permits within the radius are returned.
- **AC-6 (FR-E1/E2/E3):** *Given* stored permits, *when* `GET /api/building-permits?municipality=Thalwil` is called, *then* only Thalwil permits are returned, newest first, ≤ 500 rows.
- **AC-7 (NFR-4):** *Given* a malformed message on any consumed topic, *when* it fails 3 retries, *then* it is published to the matching `*.dlq` and processing continues.

## 8. Open Questions / Risks

- CSV header stability and the authoritative ID column from the OGD dataset (mapping must be validated against the real file).
- Ingestor's compile/runtime dependency on the persistence module's registry API — acceptable for MVP, revisit for clean service independence (see `backlog.md`).
- Geocoding accuracy/rate limits of GeoAdmin under bulk load.

## 9. Traceability

Epics A–G map to the per-module specs in `specs/` and to roadmap items in `backlog.md`.
