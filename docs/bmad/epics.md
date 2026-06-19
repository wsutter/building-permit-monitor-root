---
stepsCompleted: ["step-01-validate-prerequisites", "step-02-design-epics", "step-03-create-stories", "step-04-final-validation"]
inputDocuments:
  - docs/bmad/prd.md
  - docs/bmad/architecture.md
  - docs/bmad/backlog.md
  - docs/bmad/project-brief.md
  - docs/bmad/coding-standards.md
  - docs/bmad/specs/contracts.md
  - docs/bmad/specs/ingestor.md
  - docs/bmad/specs/normalizer.md
  - docs/bmad/specs/enricher.md
  - docs/bmad/specs/persistence.md
  - docs/bmad/specs/api.md
  - docs/bmad/specs/platform.md
scope: forward-looking
---

# building-permit-monitor - Epic Breakdown

## Overview

This document provides the epic and story breakdown for building-permit-monitor, decomposing the requirements from the PRD and Architecture into implementable stories.

**Scope: forward-looking.** This is a brownfield project (~v0.4–0.6). The Requirements Inventory below catalogs the full PRD/Architecture requirement set with an implementation-status annotation, but the **epics and stories (created in later steps) target only the remaining / open work** — the backlog near-term items, tech-debt, and planned features. Already-implemented requirements are recorded as satisfied and are not re-storied.

**Status legend:** ✅ implemented · 🟡 partial · ⬜ remaining · 🔮 planned (future).

## Requirements Inventory

### Functional Requirements

**Epic A — Ingestion (`ingestor`)**

- FR-A1 ✅ Periodically (cron) download the Canton ZH building-permit CSV from the configured `source-url`.
- FR-A2 ✅ Parse each CSV record into a `BuildingPermitRawEvent` (flat Canton-ZH schema). *Mapping validated and documented — B-01.*
- FR-A3 ✅ Compute a stable business key `externalId = id + ":" + publicationNumber`.
- FR-A4 ✅ Skip permits already seen via the raw-event registry; only publish new permits.
- FR-A5 ✅ Publish new raw events to `building-permit.raw`, keyed by external id.
- FR-A6 ✅ Prune blank/null payload fields before publishing.

**Epic B — Normalization (`normalizer`)**

- FR-B1 ✅ Consume `building-permit.raw` under consumer group `normalizer`.
- FR-B2 ✅ Map the raw Canton-ZH record into `BuildingPermitNormalizedEvent`.
- FR-B3 ✅ Classify into canonical `BuildingPermitCategory`. *Rules broadened — B-02.*
- FR-B4 🟡 Normalize status into `BuildingPermitStatus`. *Mapping to expand — B-02.*
- FR-B5 🟡 Compose a human-usable `address` (street + number, ZIP + town) and carry `municipality`. *Edge cases — B-02.*
- FR-B6 ✅ Publish to `building-permit.normalized`, keyed by `permitId`.
- FR-B7 ✅ Route failures to `building-permit.raw.dlq`.

**Epic C — Enrichment (`enricher`)**

- FR-C1 ✅ Consume `building-permit.normalized` under consumer group `enricher`.
- FR-C2 ✅ Geocode the address via the GeoAdmin Search API, using municipality as context.
- FR-C3 ✅ Return WGS84 (EPSG:4326) latitude/longitude.
- FR-C4 ✅ Set `geocodingProvider` (GEO_ADMIN) and `geocodingQuality`.
- FR-C5 ✅ Apply fallback strategy: full → reduced address → town; no marker if nothing reliable (never fabricate).
- FR-C6 ✅ Publish to `building-permit.enriched`, keyed by `permitId`.
- FR-C7 ✅ Route failures to `building-permit.normalized.dlq`.

**Epic D — Persistence (`persistence`)**

- FR-D1 ✅ Consume `building-permit.enriched` under consumer group `persistence`.
- FR-D2 ✅ Upsert into `building_permits` keyed on `(source, external_id)`; deterministic `id = nameUUIDFromBytes(permitId)`.
- FR-D3 ✅ Store `geom GEOMETRY(Point,4326)` only when both coordinates exist; store lat/lon + geocoding metadata.
- FR-D4 ✅ Store the full enriched event as `raw_payload` JSONB.
- FR-D5 ✅ Manage schema via Flyway migrations applied on startup.
- FR-D6 ✅ Maintain the raw-event registry table used for duplicate detection (FR-A4).
- FR-D7 ✅ Support spatial queries: within-radius (`ST_DWithin`) and bounding-box (`ST_MakeEnvelope && geom`). *Repository methods exist; not yet exposed via API — see FR-E4/E5.*
- FR-D8 ✅ Route failures to `building-permit.enriched.dlq`.
- FR-D9 ⬜ Maintain `updated_at` on upsert (currently only defaults on insert) — B-07.

**Epic E — Query API (`api`)**

- FR-E1 ✅ Expose `GET /api/building-permits` returning `BuildingPermitDto` records.
- FR-E2 ✅ Optional filters `municipality` and `category` via parameterized SQL.
- FR-E3 ✅ Order by `published_date DESC NULLS LAST`, cap at 500.
- FR-E4 ⬜ Bounding-box filter for map viewports (expose persistence `findVisiblePermits`) — B-03.
- FR-E5 ⬜ Radius filter (expose persistence `findWithinRadius`) — B-04.
- FR-E6 🔮 Date-range / free-text filters; streaming endpoints (SSE/WebFlux) — post-MVP (E-07).

**Epic F — Platform & Contracts (`platform`, `contracts`)**

- FR-F1 ✅ Provide local infrastructure (Kafka KRaft, PostGIS, Conduktor Console) via Podman Compose.
- FR-F2 ✅ Create the six topics (3 main + 3 DLQ), 1 partition, RF 1, 7-day retention.
- FR-F3 ✅ Centralize event classes, topic names, consumer-group ids, and DLQ error handling in `contracts`.

**Epic G — Web map (planned)**

- FR-G1 🔮 Reusable Angular 19+ library with Leaflet map, markers, filters, and detail popups, integrable into the Studio r2 web app — E-06. *Requires a UX specification before detailed stories.*

### NonFunctional Requirements

- NFR-1 ✅ Modularity — every service builds, tests, runs standalone; shared contracts only in `contracts`.
- NFR-2 ✅ Loose coupling via Kafka events. *Exception: ingestor consults the persistence registry — see AR-6 / T-01.*
- NFR-3 ✅ Idempotency — registry + `(source, external_id)` upsert.
- NFR-4 ✅ Fault isolation — DLQs (3 retries, 1 s fixed backoff); consumer never halts.
- NFR-5 ✅ Observability — Actuator (`health`, `info`, `metrics`); SLF4J→Log4j2.
- NFR-6 ✅ Coordinate correctness — lat/lon human-readable; PostGIS gets `(longitude, latitude)`.
- NFR-7 🟡 Reproducible builds — parent POM + Spotless + JaCoCo present; **CI not in repo** — AR-2 / B-06.
- NFR-8 🟡 Quality — Testcontainers used in persistence; **per-service context smoke tests missing for some services** — B-05.

### Additional Requirements

*(from Architecture + Backlog tech-debt — these drive several open stories)*

- AR-1 ✅ **Brownfield — no starter template.** The Maven multi-module project is already scaffolded; Epic-1/Story-1 does **not** need project bootstrapping.
- AR-2 ⬜ CI/CD — GitHub Actions: per-module `spotless:check` + `clean verify` on Temurin Java 25 — B-06.
- AR-3 ✅ Coordinate-order invariant must be honored in any geo-touching code (cross-cutting constraint).
- AR-4 ✅ Flyway owns the schema; `ddl-auto: validate`; new immutable, sequentially numbered migrations only.
- AR-5 ✅ Central DLQ config (`KafkaDlqConfiguration`) in `contracts`; no per-service ad-hoc error handling.
- AR-6 ⬜ Decouple `ingestor` → `persistence` registry coupling (move contract to `contracts`, or REST/Kafka interface, or accept) — **decision needed** — T-01.
- AR-7 ⬜ Contract test fixtures — golden `examples/*.json` + round-trip tests in `contracts` — T-03.
- AR-8 ⬜ Validate CSV field→domain mapping against the real OGD file (header, authoritative ID column) — B-01.
- AR-9 🟡 Reconcile `docs/README.md` superseded narrative vs. current code — T-02. *(Translation + `docs/bmad/` done; superseded design snippets in `docs/README.md` remain.)*

### UX Design Requirements

None. No UX specification document exists, and the MVP has no UI. The only UI surface is the planned `web` Angular/Leaflet map (FR-G1 / E-06); actionable UX-DRs would require a dedicated UX spec first and are therefore out of current scope.

### FR Coverage Map

**Already implemented (no epic — recorded as satisfied):** FR-A1, FR-A3, FR-A4, FR-A5, FR-A6, FR-B1, FR-B2, FR-B6, FR-B7, FR-C1–FR-C7, FR-D1–FR-D8, FR-E1, FR-E2, FR-E3, FR-F1, FR-F2, FR-F3, NFR-1–NFR-6, AR-1, AR-3, AR-4, AR-5.

| Requirement | Epic | Note |
|-------------|------|------|
| FR-A2 | Epic 1 | Validate CSV→domain mapping vs. real OGD file (B-01) |
| FR-B3 | Epic 1 | Broaden category classification (B-02) |
| FR-B4 | Epic 1 | Robust status normalization (B-02) |
| FR-B5 | Epic 1 | Address-composition edge cases (B-02) |
| FR-E4 | Epic 2 | Bounding-box endpoint (B-03) |
| FR-E5 | Epic 2 | Radius endpoint (B-04) |
| FR-D9 | Epic 3 | `updated_at` maintenance on upsert (B-07) |
| NFR-7 | Epic 3 | CI / reproducible builds (B-06 / AR-2) |
| NFR-8 | Epic 3 | Per-service smoke tests (B-05) |
| AR-2 | Epic 3 | GitHub Actions CI (B-06) |
| AR-6 | Epic 3 | Decouple ingestor↔persistence (T-01) |
| AR-7 | Epic 3 | Contract test fixtures (T-03) |
| AR-9 | Epic 3 | Doc reconciliation (T-02) |
| FR-G1 | Epic 4 | Interactive map — planned, UX-gated (E-06) |

**Deferred post-MVP (no epic this cycle):** FR-E6, extensions E-01–E-09.

## Epic List

### Epic 1: Trustworthy Permit Data
Permits flowing through the pipeline are correctly parsed, classified, statused, and addressed, so downstream geocoding, filtering, and display reflect reality. Hardens the already-built `ingestor`/`normalizer` stages.
**FRs covered:** FR-A2, FR-B3, FR-B4, FR-B5 (refs B-01, B-02)

### Epic 2: Spatial Query API
API consumers can fetch permits by map viewport (bounding box) and by radius around a point, exposing the PostGIS spatial queries already present in `persistence`. Unblocks the interactive map.
**FRs covered:** FR-E4, FR-E5 (refs B-03, B-04)

### Epic 3: Engineering Quality & Delivery Hardening
For the maintainer/reviewer persona: the project builds green in CI, carries safety-net tests and stable event contracts, tracks changes accurately, and has a clean service boundary — making it trustworthy and portfolio-ready.
**Reqs covered:** FR-D9, NFR-7, NFR-8, AR-2, AR-6, AR-7, AR-9 (refs B-05, B-06, B-07, T-01, T-03, T-02)

### Epic 4: Interactive Permit Map (planned — UX-gated)
End users view building permits on an embeddable Leaflet map (markers, filters, detail popups) in the Studio r2 web app. **Depends on Epic 2 and on a UX specification that does not yet exist** — detailed story creation is deferred until `bmad-ux` produces a UX spec; kept here as a placeholder for traceability.
**FRs covered:** FR-G1 (ref E-06)

### Dependencies
- Epics 1, 2, and 3 are independent and may be sequenced in any order or run in parallel.
- Epic 4 depends on Epic 2 (spatial API) and a UX specification.

## Epic 1: Trustworthy Permit Data

Permits flowing through the pipeline are correctly parsed, classified, statused, and addressed, so downstream geocoding, filtering, and display reflect reality. Hardens the already-built `ingestor` and `normalizer` stages.

### Story 1.1: Validate and document the CSV→domain field mapping

As a developer,
I want the Canton ZH OGD CSV columns mapped to the raw event and domain fields and verified against the live file,
So that ingestion and normalization use the correct source fields.

**Acceptance Criteria:**

**Given** the live OGD CSV at the configured `source-url`
**When** its header is inspected
**Then** every field consumed by `BuildingPermitRawEvent` and the normalizer maps to an existing column
**And** the mapping is captured in a CSV-column → domain-field table.

**Given** the source ID columns
**When** `externalId = id + ":" + publicationNumber` is computed
**Then** both `id` and `publicationNumber` are confirmed present and stable in the source.

**Given** a sample of real CSV rows
**When** ingested in a local run
**Then** they parse into `BuildingPermitRawEvent` without mapping errors
**And** blank/null fields are pruned before publishing.

**Given** any CSV column with no domain mapping
**When** the mapping is documented
**Then** it is explicitly listed as intentionally ignored or flagged for inclusion.

### Story 1.2: Broaden building-permit category classification

As an API consumer,
I want permits classified into the correct `BuildingPermitCategory`,
So that category filters return meaningful results.

**Acceptance Criteria:**

**Given** representative German project descriptions (e.g. Neubau, Umbau, Rückbau, Sanierung, Nutzungsänderung)
**When** they are normalized
**Then** each maps to the expected enum (NEW_BUILDING, RENOVATION, DEMOLITION, REFURBISHMENT, OTHER).

**Given** a description matching no rule
**When** it is classified
**Then** the category is `UNKNOWN` (never null, never invented).

**Given** the classifier
**When** unit tests run
**Then** `BuildingPermitCategoryClassifierTest` covers each category branch and the UNKNOWN fallback.

### Story 1.3: Robust status normalization

As an API consumer,
I want permit status normalized to `BuildingPermitStatus`,
So that status reflects the source consistently.

**Acceptance Criteria:**

**Given** known source status values
**When** they are normalized
**Then** they map to SUBMITTED, APPROVED, REJECTED, or WITHDRAWN as appropriate.

**Given** an unrecognized or missing status
**When** it is normalized
**Then** the status is `UNKNOWN`.

**Given** the status mapping
**When** unit tests run
**Then** the mappings and the UNKNOWN fallback are covered.

### Story 1.4: Reliable address composition

As the enricher (geocoding consumer),
I want a well-formed `address` and `municipality` on normalized events,
So that GeoAdmin geocoding succeeds more often.

**Acceptance Criteria:**

**Given** street, house number, ZIP, and town are present
**When** the event is normalized
**Then** `address` = "Street Number, ZIP Town"
**And** `municipality` is set.

**Given** a missing house number or ZIP
**When** the event is normalized
**Then** the address degrades gracefully with no leading/trailing commas and no doubled spaces.

**Given** no street is available
**When** the event is normalized
**Then** the address falls back to town/municipality and remains usable as geocoder input.

**Given** these edge cases
**When** mapper unit tests run
**Then** they are covered.

## Epic 2: Spatial Query API

API consumers can fetch permits by map viewport (bounding box) and by radius around a point, exposing the PostGIS spatial queries already present in `persistence`. Unblocks the interactive map.

### Story 2.1: Bounding-box query endpoint

As a map client,
I want to fetch permits within a lon/lat bounding box,
So that I load only what is visible in the current viewport.

**Acceptance Criteria:**

**Given** stored permits with geometry
**When** `GET /api/building-permits` is called with `minLon`, `minLat`, `maxLon`, `maxLat`
**Then** only permits whose `geom` intersects `ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)` are returned, via a parameterized query in the `api` JDBC read model.

**Given** missing or invalid bounding-box parameters
**When** the endpoint is called
**Then** a documented `400 Bad Request` is returned, not a `500`.

**Given** a result set
**When** it is returned
**Then** it consists of `BuildingPermitDto` records, stably ordered and capped at 500, consistent with the existing endpoint.

**Given** the endpoint
**When** tests run
**Then** the bounding-box filter is covered by a PostGIS-backed test (Testcontainers).

### Story 2.2: Radius query endpoint

As a search/map client,
I want permits within a radius of a point,
So that I can answer "permits near here".

**Acceptance Criteria:**

**Given** stored permits
**When** the endpoint is called with `lat`, `lon`, and `radiusMeters`
**Then** only permits within the radius are returned via `ST_DWithin(geom::geography, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radiusMeters)`.

**Given** the query
**When** the point is constructed
**Then** it is built as `(lon, lat)`, honoring the coordinate-order invariant.

**Given** missing or invalid parameters
**When** the endpoint is called
**Then** a documented `400 Bad Request` is returned, not a `500`.

**Given** a result set
**When** it is returned
**Then** it consists of `BuildingPermitDto` records, ordered and capped, and a PostGIS test covers the radius filter.

## Epic 3: Engineering Quality & Delivery Hardening

For the maintainer/reviewer persona: the project builds green in CI, carries safety-net tests and stable event contracts, tracks changes accurately, and has a clean service boundary — making it trustworthy and portfolio-ready.

### Story 3.1: GitHub Actions CI pipeline

As a maintainer/reviewer,
I want CI to build and check every module on push and pull request,
So that regressions and format violations are caught automatically.

**Acceptance Criteria:**

**Given** a push or PR to `main`
**When** CI runs
**Then** it sets up Temurin Java 25 and runs `spotless:check` then `clean verify`, failing on any error.

**Given** `contracts` is a dependency of the other modules
**When** CI runs
**Then** `contracts` is built/installed before its dependents.

**Given** a formatting violation
**When** CI runs
**Then** the build fails at `spotless:check`.

**Given** the pipeline
**When** it is committed
**Then** the workflow file exists under `.github/workflows/`.

### Story 3.2: Per-service Spring context smoke tests

As a maintainer,
I want each Spring Boot service to have a context-load test,
So that wiring, JPMS, and config errors surface early in CI.

**Acceptance Criteria:**

**Given** a Spring Boot service (ingestor, normalizer, enricher, persistence, api) lacking a smoke test
**When** one is added
**Then** a `@SpringBootTest` `contextLoads` test named `BuildingPermit<Module>ApplicationTest` exists.

**Given** the smoke test
**When** `mvn verify` runs
**Then** the context loads (using Testcontainers or test slices where infra is required) and the build passes.

### Story 3.3: Contract test fixtures and round-trip tests

As a developer,
I want golden JSON fixtures and round-trip (de)serialization tests for the three events,
So that accidental contract changes are caught.

**Acceptance Criteria:**

**Given** `examples/raw-building-permit-event.json`, `normalized-building-permit-event.json`, and `enriched-building-permit-event.json`
**When** round-trip tests run in `contracts`
**Then** each event serializes to and deserializes from its fixture without loss, including the `GeocodingProvider` and `GeocodingQuality` enums.

**Given** a breaking field change to an event record
**When** the tests run
**Then** they fail.

### Story 3.4: Maintain `updated_at` on upsert

As an API consumer/maintainer,
I want `updated_at` to reflect the last modification,
So that change-tracking and "recently updated" ordering are accurate.

**Acceptance Criteria:**

**Given** an existing permit row
**When** it is upserted again
**Then** `updated_at` is set to `now()` while `created_at` is unchanged.

**Given** a new permit
**When** it is inserted
**Then** `created_at` and `updated_at` are both `now()`.

**Given** the change
**When** it is delivered
**Then** it ships as a new immutable Flyway migration (`V<n>__...`), and a Testcontainers test verifies `updated_at` advances on re-upsert.

### Story 3.5: Decide and implement ingestor↔persistence decoupling

As a maintainer,
I want the raw-event registry dependency between `ingestor` and `persistence` resolved per a documented decision,
So that module boundaries are clean, or the coupling is consciously accepted.

**Acceptance Criteria:**

**Given** the three options (move the registry contract into `contracts`; expose it via a REST/Kafka interface; accept the coupling)
**When** a decision is made
**Then** it is recorded as an ADR update to `architecture.md` (revising AD-7).

**Given** a decision to decouple
**When** it is implemented
**Then** `ingestor` no longer imports `persistence.api.*` (or imports only a `contracts`-level interface), and the pipeline still deduplicates correctly (tests pass).

**Given** a decision to accept the coupling
**When** it is recorded
**Then** AD-7 is marked accepted with rationale and no code change is required.

### Story 3.6: Reconcile superseded snippets in `docs/README.md`

As a reader,
I want `docs/README.md` to not contradict the implemented code,
So that the documentation is trustworthy.

**Acceptance Criteria:**

**Given** the known superseded snippets (inline-SQL API controller, `Map`-payload raw event, single-`V1` migration narrative)
**When** they are reconciled
**Then** `docs/README.md` reflects the current implementation (parameterized API, flat raw schema, `V1` registry + `V2` PostGIS) or clearly marks them as historical.

**Given** `docs/bmad/` is the source of truth
**When** reconciliation is complete
**Then** no statement in `docs/README.md` contradicts `docs/bmad/` without a "historical/superseded" note.

## Epic 4: Interactive Permit Map (planned — UX-gated)

End users view building permits on an embeddable Leaflet map (markers, filters, detail popups) in the Studio r2 web app. This epic depends on Epic 2 (spatial API) and on a UX specification that does not yet exist.

### Story 4.1: Embeddable permit map (deferred)

As an end user,
I want to see building permits on an embeddable Leaflet map with markers, filters, and detail popups in the Studio r2 web app,
So that I can explore building activity visually.

**Acceptance Criteria:**

⏸️ **Deferred.** Detailed acceptance criteria are intentionally not yet defined. This story depends on Epic 2 (spatial query API) and a UX specification. Expand it after running `bmad-ux` to produce the UX spec; retained here for FR-G1 traceability.
