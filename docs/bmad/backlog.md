# Backlog & Roadmap — Building Permit Monitor

> BMAD planning artifact · Author: Walter Sutter · Date: 2026-06-12 · Status: draft
> Consolidates the roadmap, post-MVP extensions, and refactor candidates from `docs/README.md` plus gaps observed in the current source. Ordered roughly by value/sequence; not yet sprint-planned.

## Legend

- ✅ done · 🟡 partial / in progress · ⬜ not started

## 1. Current State Snapshot

| Capability | State |
|------------|:----:|
| Platform (Podman Compose: Kafka, PostGIS, Conduktor) + topic script | ✅ |
| `contracts` (events, topics, groups, enums, DLQ config) | ✅ |
| Ingestor (scheduled CSV poll, dedup, raw events) | ✅ |
| Normalizer (mapping + category classifier) | 🟡 (classifier + mapper present; status mapping & rules to expand) |
| Enricher (GeoAdmin geocoding → enriched) | ✅ |
| Persistence (idempotent PostGIS upsert, registry, spatial queries) | ✅ |
| API (`GET /api/building-permits`, municipality/category filter) | ✅ |
| Web Angular/Leaflet library | ⬜ |
| Kubernetes / Google Cloud deployment | ⬜ |
| GitHub Actions CI | ⬜ (defined in vision doc, not in repo) |

## 2. Near-Term Backlog (next increments)

| ID | Item | Rationale | Refs |
|----|------|-----------|------|
| B-01 | **Validate CSV mapping against the real OGD file** — confirm headers, the authoritative ID column, and field→domain mapping table | De-risks all downstream stages; vision doc flags this as the immediate next step | ingestor spec, PRD FR-A2/A3 |
| B-02 | **Expand normalizer rules** — robust status normalization to `BuildingPermitStatus`, broaden category classification, address composition edge cases | Currently `UNKNOWN`-heavy; improves data quality | normalizer spec, PRD FR-B3/B4/B5 |
| B-03 | **API bounding-box endpoint** — expose `findVisiblePermits` for map viewports | Persistence already supports it; unblocks the web map | PRD FR-E4 |
| B-04 | **API radius endpoint** — expose `findWithinRadius` | Showcases the core PostGIS value proposition | PRD FR-E5 |
| B-05 | **Per-service context smoke tests** for any service missing one (`@SpringBootTest contextLoads`) | Cheapest way to catch wiring/JPMS/config errors early | coding-standards §10 |
| B-06 | **GitHub Actions CI** — per-module `spotless:check` + `clean verify` on Temurin Java 25 | Reproducible, reviewable builds; portfolio signal | coding-standards §11 |
| B-07 | **`updated_at` maintenance on upsert** — trigger or explicit bump | `updated_at` currently only defaults on insert | persistence spec (Future) |

## 3. Refactor / Tech-Debt Candidates

| ID | Item | Notes |
|----|------|-------|
| T-01 | **Decouple ingestor from persistence** | Ingestor imports `persistence.api.BuildingPermitRawEventRegistry` (build + runtime coupling). Options: move the registry contract into `contracts`, expose it via a small REST/Kafka interface, or accept the coupling for MVP. Decision needed. |
| T-02 | **Reconcile docs vs. implementation** | The German `docs/README.md` shows an older inline-string API controller, a `Map`-payload raw event, and a single `V1__create_building_permits.sql`. The code has moved on (parameterized API, flat raw schema, `V1` registry + `V2` PostGIS). Keep `docs/bmad/` as the current truth; update `docs/README.md` when convenient. |
| T-03 | **Contract test fixtures** | Add `examples/*.json` golden files + round-trip tests in `contracts` as event shapes stabilize. |

## 4. Post-MVP Extensions (vision)

- **E-01 Geodata enrichment:** municipality boundaries, building zones, public-transport stops, noise zones, flood zones.
- **E-02 Risk Analyzer:** per-permit score `noise + flood + slope + traffic`.
- **E-03 Housing Market Stream:** rents, vacancy rates, building activity, housing stock.
- **E-04 Kafka Streams aggregations:** permits per municipality/week, per category, moving averages, hotspots → topics `building-permit.statistics.{daily,weekly,by-municipality}` and `building-permit.alerts`.
- **E-05 GPKG import path** for richer GIS data (geometries, spatial queries) alongside CSV.
- **E-06 Web map:** Angular 19+ Leaflet library — markers, filters, detail popups, integrated into the Studio r2 web app.
- **E-07 Streaming API:** SSE / WebFlux endpoints.
- **E-08 Multi-canton / multi-source** ingestion (project name is already generic).
- **E-09 Kubernetes + Google Cloud** (`europe-west6`) deployment with Helm; Cloud SQL/PostGIS.

## 5. Reference Roadmap (from vision doc)

| Version | Theme |
|---------|-------|
| 0.1 | Compose + Kafka + PostGIS + manual test events |
| 0.2 | CSV ingestor + raw topic + Conduktor |
| 0.3 | Normalizer + normalized topic + basic category detection |
| 0.4 | Persistence to PostGIS + REST API |
| 0.5 | Angular library + map with markers |
| 0.6 | GeoAdmin geocoding + WGS84 + PostGIS geometries (+ optional GPKG) |
| 0.7 | First statistics, permits per municipality, time filters |
| 1.0 | Stable demo, README + screenshots, CI, optional VPS deploy |

> Against this roadmap the project is around **0.4–0.6**: pipeline + persistence + API + GeoAdmin geocoding are in place; the web map (0.5) and statistics (0.7) are open.

## 6. Known Limitations (carry into any release notes)

- Freshness depends on the upstream OGD dataset; fields may be missing/renamed.
- Geocoding can fail or return approximate hits; quality must be surfaced, never hidden; municipality centroids are approximate only.
- Local failure handling is minimal (log + restart); production needs retries, health checks, backoff.
- **Not an authoritative/legal source** — technical prototype only.
