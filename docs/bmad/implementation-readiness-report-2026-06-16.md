---
stepsCompleted: ["step-01-document-discovery", "step-02-prd-analysis", "step-03-epic-coverage-validation", "step-04-ux-alignment", "step-05-epic-quality-review", "step-06-final-assessment"]
inputDocuments:
  - docs/bmad/prd.md
  - docs/bmad/architecture.md
  - docs/bmad/epics.md
  - docs/bmad/backlog.md
  - docs/bmad/coding-standards.md
  - docs/bmad/project-brief.md
  - docs/bmad/specs/contracts.md
  - docs/bmad/specs/ingestor.md
  - docs/bmad/specs/normalizer.md
  - docs/bmad/specs/enricher.md
  - docs/bmad/specs/persistence.md
  - docs/bmad/specs/api.md
  - docs/bmad/specs/platform.md
uxDocument: none (no UI in MVP; web map FR-G1 is planned/UX-gated)
scope: forward-looking
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-16
**Project:** building-permit-monitor

## Document Inventory

| Type | File | Format | Status |
|------|------|--------|--------|
| PRD | `docs/bmad/prd.md` | whole | ✅ found |
| Architecture | `docs/bmad/architecture.md` | whole | ✅ found |
| Epics & Stories | `docs/bmad/epics.md` | whole | ✅ found |
| UX Design | — | — | ⚠️ none (MVP has no UI; FR-G1 web map planned/UX-gated) |

**Supporting documents:** `backlog.md`, `coding-standards.md`, `project-brief.md`, `specs/*.md` (7 module specs).

**Discovery issues:** No duplicate/sharded conflicts. UX document intentionally absent.

## PRD Analysis

Source: `docs/bmad/prd.md` (read in full).

### Functional Requirements

Requirements are organized by epic area (A–G); `(planned)` marks not-yet-implemented items as labelled in the PRD.

**Epic A — Ingestion**
- FR-A1: Periodically (cron) download the Canton ZH building-permit CSV from the configured `source-url`.
- FR-A2: Parse each CSV record into a `BuildingPermitRawEvent` (flat Canton-ZH schema).
- FR-A3: Compute a stable business key `externalId = id + ":" + publicationNumber`.
- FR-A4: Skip already-seen permits via the raw-event registry; publish only new permits.
- FR-A5: Publish new raw events to `building-permit.raw`, keyed by external id.
- FR-A6: Prune blank/null payload fields before publishing.

**Epic B — Normalization**
- FR-B1: Consume `building-permit.raw` under consumer group `normalizer`.
- FR-B2: Map raw record into `BuildingPermitNormalizedEvent`.
- FR-B3: Classify into canonical `BuildingPermitCategory`.
- FR-B4: Normalize status into `BuildingPermitStatus`.
- FR-B5: Compose human-usable `address` and carry `municipality`.
- FR-B6: Publish to `building-permit.normalized`, keyed by `permitId`.
- FR-B7: Route failures to `building-permit.raw.dlq`.

**Epic C — Enrichment**
- FR-C1: Consume `building-permit.normalized` under consumer group `enricher`.
- FR-C2: Geocode the address via GeoAdmin, using municipality as context.
- FR-C3: Return WGS84 (EPSG:4326) latitude/longitude.
- FR-C4: Set `geocodingProvider` and `geocodingQuality`.
- FR-C5: Fallback strategy; never fabricate coordinates.
- FR-C6: Publish to `building-permit.enriched`, keyed by `permitId`.
- FR-C7: Route failures to `building-permit.normalized.dlq`.

**Epic D — Persistence**
- FR-D1: Consume `building-permit.enriched` under consumer group `persistence`.
- FR-D2: Upsert into `building_permits` keyed on `(source, external_id)`; deterministic `id`.
- FR-D3: Store PostGIS `geom GEOMETRY(Point,4326)` when both coords exist; store lat/lon + geocoding metadata.
- FR-D4: Store full enriched event as `raw_payload` JSONB.
- FR-D5: Manage schema via Flyway migrations on startup.
- FR-D6: Maintain the raw-event registry table for duplicate detection.
- FR-D7: Support spatial queries (within-radius, bounding-box).
- FR-D8: Route failures to `building-permit.enriched.dlq`.

**Epic E — Query API**
- FR-E1: Expose `GET /api/building-permits` returning `BuildingPermitDto` records.
- FR-E2: Optional `municipality`/`category` filters via parameterized SQL.
- FR-E3: Order by `published_date DESC NULLS LAST`, cap at 500.
- FR-E4 (planned): Bounding-box filter for map viewports.
- FR-E5 (planned): Date-range and free-text filters; streaming endpoints (SSE/WebFlux).

**Epic F — Platform & Contracts**
- FR-F1: Provide local infrastructure (Kafka KRaft, PostGIS, Conduktor) via Podman Compose.
- FR-F2: Create the six topics (3 main + 3 DLQ), 1 partition, RF 1, 7-day retention.
- FR-F3: Centralize event classes, topic names, consumer-group ids, and DLQ handling in `contracts`.

**Epic G — Web map**
- FR-G1 (planned): Reusable Angular 19+ Leaflet map library integrable into the Studio r2 web app.

**Total FRs: 37** (A:6, B:7, C:7, D:8, E:5, F:3, G:1).

### Non-Functional Requirements

- NFR-1: Modularity — every service builds/tests/runs standalone; shared code only in `contracts`.
- NFR-2: Loose coupling via Kafka (exception: ingestor→persistence registry).
- NFR-3: Idempotency — registry + `(source, external_id)` upsert.
- NFR-4: Fault isolation — DLQs (3 retries, 1 s backoff); consumer never halts.
- NFR-5: Observability — Actuator (`health`,`info`,`metrics`); SLF4J→Log4j2.
- NFR-6: Coordinate correctness — lat/lon human-readable; PostGIS gets `(lon, lat)`.
- NFR-7: Reproducible builds — parent POM pins versions; Spotless; JaCoCo.
- NFR-8: Quality — context smoke test per service; PostGIS tests via Testcontainers.

**Total NFRs: 8.**

### Additional Requirements

- Data contracts (authoritative shapes): `BuildingPermitRawEvent` (+ `externalId()`), `BuildingPermitNormalizedEvent`, `BuildingPermitEnrichedEvent` — see `specs/contracts.md`.
- PRD open questions/risks: CSV header/ID-column stability; ingestor↔persistence registry coupling; GeoAdmin accuracy/rate limits.

### PRD Completeness Assessment

The PRD is complete, internally consistent, and traceable: every FR has a clear owner module, MVP acceptance criteria (AC-1…AC-7) are expressed in Given/When/Then, and planned items are explicitly marked. Suitable as the authoritative requirements baseline. **Note for coverage validation:** the PRD's FR set is A1–A6, B1–B7, C1–C7, D1–D8, E1–E5, F1–F3, G1 — the `epics.md` requirement IDs introduce additional/renumbered items (FR-D9, an E-series radius requirement) sourced from `backlog.md`; this PRD↔Epics numbering delta is assessed in the next section.

## Epic Coverage Validation

Source: `docs/bmad/epics.md` (read in full, including the FR Coverage Map and all 4 epics / 13 stories). Scope is **forward-looking**: already-implemented PRD FRs are recorded as satisfied (no epic); only open work is storied.

### Coverage Matrix

| PRD FR | Epic / Story coverage | Status |
|--------|-----------------------|--------|
| FR-A1, A3, A4, A5, A6 | — (already implemented) | ✅ Satisfied |
| FR-A2 | Epic 1 / Story 1.1 | ✓ Covered |
| FR-B1, B2, B6, B7 | — (already implemented) | ✅ Satisfied |
| FR-B3 | Epic 1 / Story 1.2 | ✓ Covered |
| FR-B4 | Epic 1 / Story 1.3 | ✓ Covered |
| FR-B5 | Epic 1 / Story 1.4 | ✓ Covered |
| FR-C1…C7 | — (already implemented) | ✅ Satisfied |
| FR-D1…D8 | — (already implemented) | ✅ Satisfied |
| FR-E1, E2, E3 | — (already implemented) | ✅ Satisfied |
| FR-E4 (bounding-box, planned) | Epic 2 / Story 2.1 | ✓ Covered |
| FR-E5 (date-range/free-text/streaming, planned) | **Not storied** — appears in epics as deferred "FR-E6" | ⚠️ Deferred (renumbered) |
| FR-F1, F2, F3 | — (already implemented) | ✅ Satisfied |
| FR-G1 (web map, planned) | Epic 4 / Story 4.1 (placeholder, no ACs) | ⚠️ Deferred (UX-gated, not build-ready) |

### Requirements in Epics NOT in the PRD

| Epics ID | Story | Source | Note |
|----------|-------|--------|------|
| FR-D9 (`updated_at` on upsert) | Epic 3 / Story 3.4 | backlog B-07 | Not a PRD FR — introduced during epic creation |
| FR-E5 (radius endpoint) — *clashes with PRD FR-E5* | Epic 2 / Story 2.2 | backlog B-04 | epics reused the `FR-E5` id for "radius", pushing the PRD's FR-E5 to "FR-E6" |

NFR/Additional coverage (informational): NFR-7→Story 3.1, NFR-8→Story 3.2, AR-7→Story 3.3, AR-6→Story 3.5, AR-9→Story 3.6.

### Missing Requirements

- **No PRD FR is unaccounted for.** All 37 are either satisfied, story-covered, or consciously deferred.
- **No critical missing coverage.** The two ⚠️ items (FR-E5 date-range/streaming, FR-G1 web map) are PRD-`(planned)` items deferred by design under forward-looking scope.

### Findings (traceability)

1. **[Medium] FR numbering divergence between PRD and Epics.** `epics.md` introduced `FR-D9` and re-used `FR-E5` for the radius endpoint (renumbering the PRD's FR-E5 → "FR-E6"). Both new items are legitimate, sourced from `backlog.md` (B-07, B-04), but the ID clash breaks clean PRD↔Epics traceability.
   - **Recommendation:** reconcile the IDs — preferably add the two backlog-sourced requirements to the PRD with non-clashing IDs (e.g. `FR-D9` updated_at; a new `FR-E` for radius) and keep the PRD's `FR-E5` = date-range/free-text/streaming. Alternatively, in `epics.md` refer to the radius item by its backlog id (B-04) instead of `FR-E5`.
   - ✅ **Resolved 2026-06-16:** the PRD was updated to add `FR-D9` (updated_at) to Epic D and to split Query API planned items into `FR-E4` (bounding-box), `FR-E5` (radius), `FR-E6` (date-range/free-text/streaming) — matching `epics.md` exactly. PRD↔Epics FR numbering is now consistent (PRD now: D1–D9, E1–E6; total **39 FRs**). The "Requirements in Epics NOT in the PRD" table above is therefore no longer applicable.
2. **[Low/expected] FR-G1 (web map) is a placeholder** with no acceptance criteria (UX-gated). Not build-ready by design; expand after `bmad-ux`.
3. **[Low/expected] FR-E5 (date-range/free-text/streaming)** is deferred post-MVP with no placeholder story; it is captured in the epics "Deferred post-MVP" list (as FR-E6). Acceptable; fold the ID fix from Finding 1.

### Coverage Statistics

- Total PRD FRs: **37**
- Already implemented (satisfied, no epic): **30**
- Covered by an in-scope story: **5** (FR-A2, FR-B3, FR-B4, FR-B5, FR-E4)
- Consciously deferred (planned): **2** (FR-E5 date-range/streaming, FR-G1 web map)
- Unaccounted / critical gaps: **0**
- **Accounted-for coverage: 37/37 = 100%** (with 2 deferred by design; 1 medium ID-reconciliation finding)

## UX Alignment Assessment

### UX Document Status

**Not Found.** No `*ux*.md` exists in `docs/bmad/`.

### Is UX Implied?

**Partially — and only for deferred scope.**
- The **MVP has no UI**: ingestion → normalization → enrichment → persistence → REST API are all non-visual. No UX spec is required for any in-scope (Epic 1–3) story.
- A UI **is** implied for the **planned** web map: FR-G1 / Epic 4 (`web` Angular + Leaflet library) and the Studio r2 host app. This is explicitly deferred and UX-gated.

### Alignment Issues

- None to assess between UX↔PRD↔Architecture (no UX document, no in-scope UI).
- **Architecture↔future-UI consistency is sound:** `architecture.md` already accounts for the eventual UI via the `api` REST read model and the planned `web` library, and Epic 2's spatial endpoints (bounding-box/radius) are the architectural enabler the map will consume. No architectural gap blocks the future UI — only the missing UX spec does.

### Warnings

- ⚠️ **UX specification required before Epic 4 (FR-G1) becomes build-ready.** Run `bmad-ux` to produce it; until then Story 4.1 correctly remains a placeholder. This is a *gating prerequisite for deferred scope*, **not** a blocker for the in-scope Epics 1–3.

## Epic Quality Review

Epics and stories assessed against the create-epics-and-stories best practices (user value, independence, no forward dependencies, sizing, AC quality, brownfield fit).

### Best-practices compliance

| Epic | User value | Independent | Stories sized | No forward deps | ACs testable | FR traceable |
|------|:---------:|:-----------:|:-------------:|:---------------:|:------------:|:------------:|
| 1 — Trustworthy Permit Data | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 — Spatial Query API | ✅ | ✅ | ✅ | ✅ | ✅ (incl. 400 error paths) | ✅ |
| 3 — Engineering Quality & Delivery Hardening | ⚠️ maintainer-value | ✅ | ✅ | ✅ | ✅ | ✅ |
| 4 — Interactive Permit Map | ✅ (deferred) | depends on Epic 2 + UX (allowed) | n/a | n/a | ❌ none (deferred) | ✅ |

**Dependency analysis:** Epics 1/2/3 are mutually independent; Epic 4 depends only on an *earlier* epic (2) plus a UX spec — no epic requires a future epic, no circular or forward story dependencies found. Within every epic, stories build solely on prior ones.

**Brownfield fit:** Architecture confirms **no starter template** (AR-1), so the absence of a project-setup Story 1.1 is correct. Stories integrate with existing services; Story 3.5 (decoupling) and Story 3.6 (doc reconciliation) are appropriate brownfield compatibility/refactor stories. No bulk-upfront schema creation — Story 3.4 adds a single targeted migration only when needed.

### Findings by severity

#### 🔴 Critical Violations
None.

#### 🟠 Major Issues
None blocking.

#### 🟡 Minor Concerns / Accepted Deviations
1. **Epic 3 is a cross-cutting quality/hardening epic, not direct end-user value.** Strict create-epics guidance flags CI/quality work as non-user epics. **Mitigation:** it is framed around the maintainer/reviewer personas (P1, P3) defined in the PRD, is consolidated into one epic (not fragmented technical layers), and was explicitly reviewed and approved. **Remediation option:** distribute its stories into the feature epics. **Recommendation:** keep as-is — the deviation is conscious and justified for a portfolio project.
2. **Story 4.1 (web map) intentionally has no acceptance criteria** (deferred, UX-gated). **Action:** do not pull into a sprint until expanded via `bmad-ux`. Correctly flagged in the epics doc.
3. **Story 3.5 has decision-conditional ACs** (decide among 3 options, then implement). Acceptable for a decision-first story; **recommendation:** make the AD-7 decision before sprint-loading so the story carries a single concrete path.
4. **FR-numbering divergence (carried from Coverage Validation):** `epics.md` added `FR-D9` and reused `FR-E5` for radius. Minor traceability issue; reconcile per the Coverage Validation recommendation.

### Remediation summary

All four findings are Minor/accepted. None block starting the in-scope feature work (Epics 1–2, and the non-decision stories of Epic 3). Recommended pre-sprint cleanups: (a) reconcile the FR numbering (Finding 1/4), (b) settle the Story 3.5 decision, (c) leave Story 4.1 out of sprint scope until `bmad-ux` runs.

## Summary and Recommendations

### Overall Readiness Status

🟢 **READY** — for in-scope implementation (Epics 1–3). No critical or blocking issues. Four minor/accepted findings, all with clear remediation; Epic 4 is intentionally deferred (UX-gated).

The planning set is unusually solid for a brownfield project: PRD, Architecture, and Epics are complete, internally consistent, and traceable; 100% of PRD FRs are accounted for; the already-implemented MVP (~v0.4–0.6) is correctly recorded as satisfied rather than re-storied.

### Critical Issues Requiring Immediate Action

None. There are no 🔴 critical or blocking 🟠 major issues. Implementation of Epics 1–2 and the non-decision stories of Epic 3 can begin immediately.

### Recommended Next Steps (pre-/early-sprint, in priority order)

1. **Reconcile FR numbering (Medium).** `epics.md` added `FR-D9` and reused `FR-E5` for the radius endpoint, clashing with the PRD's `FR-E5` (date-range/streaming). Either add the backlog-sourced items to the PRD with clean IDs, or reference them by backlog id (B-04, B-07) in the epics. Keeps PRD↔Epics traceability intact.
2. **Settle the Story 3.5 architecture decision (AD-7)** — decide among the three ingestor↔persistence decoupling options before sprint-loading, so the story carries one concrete implementation path.
3. **Keep Story 4.1 / Epic 4 out of sprint scope** until `bmad-ux` produces a UX spec; then expand its acceptance criteria.
4. **(Optional) Reconsider Epic 3 framing** — accepted as a maintainer/reviewer-value epic; only revisit if you'd prefer those quality stories distributed into the feature epics.

### Final Note

This assessment reviewed 5 dimensions (document discovery, PRD analysis, FR coverage, UX alignment, epic quality) and identified **4 minor/accepted issues across 2 categories (traceability, deferred-scope)** — **0 critical, 0 blocking**. The artifacts are ready to proceed to Sprint Planning. Address recommendation #1 (and ideally #2) before or early in the first sprint; the rest are non-blocking. You may proceed as-is and fix #1 opportunistically.

**Assessor:** Implementation Readiness review (BMad) · **Date:** 2026-06-16
