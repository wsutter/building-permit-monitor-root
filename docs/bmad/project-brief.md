# Project Brief — Building Permit Monitor

> BMAD planning artifact · Author: Walter Sutter · Date: 2026-06-12 · Status: draft
> Synthesized from `README.md`, `docs/README.md` (DE), the service READMEs, and the current source tree. Not a substitute for the canonical docs — it distills them into a BMAD-style brief.

## 1. Summary

**Building Permit Monitor** is a real-time, event-driven platform that collects, normalizes, enriches, and stores public building-permit publications for the **Canton of Zurich**. It ingests open government data, flows it through an Apache Kafka pipeline (raw → normalized → enriched), persists it in PostgreSQL/PostGIS, and exposes it through a REST API — with a reusable Angular/Leaflet map module planned as the visualization layer.

The project runs under the **Studio r2** brand (<https://www.studio-r2.ch>) and is built primarily as a realistic, portfolio-grade event-streaming prototype that combines Kafka, Spring Boot 4 / Java 25, open data, geospatial processing (PostGIS), and REST API design.

## 2. Problem & Opportunity

Public building-permit data for the Canton of Zurich is published as open data (CSV / HTML / GPKG) but is not delivered as a stream, is not geocoded to coordinates usable by web maps, and is not queryable in a spatial database. There is no easy way to ask questions like *"which permits were filed within 500 m of this station this month?"*

The opportunity is a loosely coupled pipeline that turns periodic open-data snapshots into a continuously updated, geocoded, spatially queryable dataset — each stage independently deployable, testable, and publishable as its own repository.

## 3. Goals

| # | Goal | Success signal |
|---|------|----------------|
| G1 | Periodically import Canton ZH building-permit data | Ingestor polls the OGD CSV on a schedule and emits raw events |
| G2 | Publish raw data as Kafka events | `building-permit.raw` receives one event per new permit |
| G3 | Normalize into a stable domain model | `building-permit.normalized` carries `BuildingPermitNormalizedEvent` with canonical category/status |
| G4 | Geocode to WGS84 coordinates | Enricher resolves addresses via GeoAdmin; `building-permit.enriched` carries lat/lon + quality |
| G5 | Persist in PostGIS, idempotently | `building_permits` table populated, no duplicates, `geom GEOMETRY(Point,4326)` set |
| G6 | Expose data via REST | `GET /api/building-permits` returns filtered permits |
| G7 | Detect new vs. already-seen permits | Duplicate raw events skipped via the raw-event registry |
| G8 (planned) | Visualize on an embeddable map | Angular library renders markers + popups in the Studio r2 web app |

## 4. Scope

### In scope (MVP)
- Single data source: **Canton of Zurich** (project name stays generic for later expansion).
- CSV ingestion, Kafka pipeline (raw/normalized/enriched + DLQs), PostGIS persistence, REST API.
- GeoAdmin address geocoding to WGS84.
- New/changed-entry detection via stable external ID.
- Local infrastructure via Podman Compose (Kafka KRaft, PostGIS, Conduktor Console).

### Out of scope (deferred — see `backlog.md`)
- Full parcel/zoning analysis, noise & flood risk, real-estate pricing, ML classification.
- Multi-canton data integration.
- Production-grade user management.
- Avro/Protobuf schemas (MVP uses JSON).
- Kubernetes / Google Cloud production operation (prepared for, not operated).

## 5. Users & Stakeholders

- **Primary:** Studio r2 (Walter) — owner, developer, portfolio author. The system is a showcase of streaming + geospatial engineering.
- **Consumers:** the Studio r2 web app and external API clients that need geocoded permit data.
- **Reviewers/recruiters:** an implicit audience — each microservice is meant to stand alone as a readable, well-tested repository.

## 6. Constraints & Assumptions

- **Tech baseline is fixed:** Java 25, Spring Boot 4, Maven, Apache Kafka (KRaft), PostgreSQL/PostGIS, Flyway. See `architecture.md`.
- **Microservice-first** by deliberate choice (not a monolith) so each service can be published independently.
- Data freshness depends entirely on the upstream OGD dataset; fields may be missing or renamed.
- Geocoding can fail or return approximate hits; results must be treated as non-authoritative.
- **Not an authoritative/legal source** — this is a technical prototype, not an official permit register.

## 7. Current State (as of 2026-06-12)

Implemented and present in the repo: `contracts`, `ingestor`, `normalizer`, `enricher`, `persistence`, `api` (Spring Boot services + shared library), and `platform` (Podman Compose + topic scripts). Two Flyway migrations exist (`raw_event_registry`, `postgis + building_permits`). The `web` Angular library and streaming/statistics endpoints described in the vision doc are **not yet built**.

## 8. Related Artifacts

- Product requirements → `prd.md`
- Technical architecture → `architecture.md`
- Engineering conventions → `coding-standards.md`
- Per-module specs → `specs/*.md`
- Roadmap & deferred work → `backlog.md`
