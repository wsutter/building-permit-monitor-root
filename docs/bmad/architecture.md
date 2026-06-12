# Architecture — Building Permit Monitor

> BMAD planning artifact · Author: Walter Sutter · Date: 2026-06-12 · Status: draft
> Grounded in the source tree, `pom.xml`, the Flyway migrations, the service `application.yml` files, and `docs/README.md`. Diagrams referenced here live as PlantUML/PNG under `docs/architecture/`.

## 1. Architectural Style

Event-driven **microservice pipeline** on Apache Kafka. Services are loosely coupled and communicate primarily through asynchronous events rather than synchronous REST. PostgreSQL/PostGIS is the read model that the API serves.

The microservice-first cut (over a modular monolith) is a deliberate decision so each service can be published, documented, and reviewed as an independent repository. See "Key Decisions" below.

## 2. System Context

- **External data source:** Canton of Zurich open-data CSV (Statistisches Amt Kanton Zürich / `datenkatalog.statistik.zh.ch`).
- **External service:** Swiss GeoAdmin Search API (`api3.geo.admin.ch`) for geocoding.
- **Consumers:** the Studio r2 web app and external API clients.

Diagrams: `docs/architecture/system-context.png`, `docs/architecture/target-architecture.png`.

## 3. Pipeline & Data Flow

```
Open Data CSV
    │
    ▼
ingestor ───────────────────────────────────► building-permit.raw
    │ (dedup via persistence raw-event registry)
    ▼
normalizer  ──(error)──► building-permit.raw.dlq
    │
    ▼
building-permit.normalized
    │
    ▼
enricher    ──(error)──► building-permit.normalized.dlq
    │ (GeoAdmin geocoding → WGS84)
    ▼
building-permit.enriched
    │
    ▼
persistence ──(error)──► building-permit.enriched.dlq
    │ (idempotent upsert)
    ▼
PostgreSQL / PostGIS
    │
    ▼
api  ──►  GET /api/building-permits  ──►  (planned) web Angular/Leaflet library
```

Diagrams: `docs/architecture/microservice-architecture.png`, `docs/architecture/kafka-event-flow.png`, `docs/architecture/local-podman-compose-deployment.png`.

## 4. Modules

| Module | Type | Spring Boot? | Responsibility |
|--------|------|:-----------:|----------------|
| `platform` | Infrastructure repo | No | Podman Compose (Kafka, PostGIS, Conduktor), topic creation scripts |
| `contracts` | Java library | No | Event records, topic & consumer-group constants, shared models, DLQ config, Jackson/Kafka config |
| `ingestor` | Microservice | Yes | Poll OGD CSV, dedup, publish raw events |
| `normalizer` | Microservice | Yes | Map raw → normalized, classify category & status |
| `enricher` | Microservice | Yes | GeoAdmin geocoding → enriched events |
| `persistence` | Microservice | Yes | Idempotent upsert into PostGIS; raw-event registry; spatial queries |
| `api` | Microservice | Yes | REST query API over the read model |
| `web` | Angular library | No | **(planned)** reusable Leaflet map module |

Maven `groupId` for all Java modules: `ch.studio-r2.building-permit-monitor`. Java package base (no hyphens, JPMS-compatible): `ch.studior2.buildingpermitmonitor`. Each Java module ships a `module-info.java` (JPMS); Spring reflection packages are explicitly `opens`-ed, DTO/event packages are `exports`-ed.

## 5. Messaging Design

- **Broker:** Apache Kafka in **KRaft mode** (no ZooKeeper).
- **Topics** (1 partition, replication factor 1, 7-day retention — local/MVP defaults):
  - `building-permit.raw`, `building-permit.normalized`, `building-permit.enriched`
  - `building-permit.raw.dlq`, `building-permit.normalized.dlq`, `building-permit.enriched.dlq`
- **Keys:** raw keyed by external id; normalized/enriched keyed by `permitId`.
- **Serialization:** JSON via Spring Kafka `JacksonJsonSerializer` / `JacksonJsonDeserializer`; consumers trust `ch.studior2.buildingpermitmonitor.*`. (Avro/Protobuf deliberately deferred.)
- **Consumer groups:** `normalizer`, `enricher`, `persistence` (constants in `contracts`).
- **DLQ routing:** a central `KafkaDlqConfiguration` in `contracts` provides a `DefaultErrorHandler` + `DeadLetterPublishingRecoverer` (`FixedBackOff(1s, 3 retries)`), mapping each source topic to its `.dlq` by `record.topic()`. Imported by the consuming services. The ingestor (producer-only) does not need it.

## 6. Persistence & Geospatial Design

- **Database:** PostgreSQL with the **PostGIS** extension (`postgis/postgis:17-3.5` locally).
- **Migrations (Flyway, run on persistence startup):**
  - `V1__create_building_permit_raw_event_registry.sql` — dedup registry keyed on `external_id`.
  - `V2__create_extension_postgis.sql` — enables PostGIS and creates `building_permits` (incl. `geom GEOMETRY(Point,4326)`, GIST index, `raw_payload JSONB`, `UNIQUE(source, external_id)`).
- **ORM:** Spring Data JPA + Hibernate, **Hibernate Spatial** + **JTS** (`org.locationtech.jts.geom.Point`) for geometry; `@JdbcTypeCode(SqlTypes.GEOMETRY)` and `SqlTypes.JSON` for `geom` / `raw_payload`. `ddl-auto: validate` (Flyway owns the schema).
- **Identity & idempotency:** business key `(source, external_id)`; primary key `id = UUID.nameUUIDFromBytes(permitId)` (deterministic) so re-delivery upserts the same row.
- **Spatial queries:** native PostGIS — `ST_DWithin(geom::geography, :point::geography, :radius)` for radius; `geom && ST_MakeEnvelope(minLon, minLat, maxLon, maxLat, 4326)` for bounding box.

### Coordinate-order invariant (critical)
Events and DTOs expose human-readable `latitude` / `longitude`. PostGIS point construction takes **`(longitude, latitude)`** — `ST_MakePoint(lon, lat)` / `ST_SetSRID(..., 4326)`. Leaflet markers use `[lat, lon]`. Geocoding uses `spatial-reference: 4326` so no coordinate transformation is needed. Mixing this order up is the single easiest geospatial bug here.

## 7. API Layer

- `api` is a Spring Boot service that reads PostGIS via **`NamedParameterJdbcTemplate`** (parameterized SQL — the SQL-injection-safe form; the inline-string version in the vision doc is superseded).
- `GET /api/building-permits` → `List<BuildingPermitDto>`, optional `municipality` / `category` filters, ordered `published_date DESC NULLS LAST`, `LIMIT 500`.
- `api` has no Kafka dependency; it is a pure read model over the database.

## 8. Cross-Cutting Concerns

- **Build:** Maven multi-module under a central parent POM pinning Java 25, Spring Boot 4.0.6, JUnit 6, and plugin versions. See `coding-standards.md`.
- **Formatting:** Spotless (Palantir/Google Java Format) enforced at `verify`.
- **Coverage:** JaCoCo.
- **Logging:** SLF4J API → Log4j2 runtime (`spring-boot-starter-logging` excluded, `spring-boot-starter-log4j2` added), config in `log4j2-spring.xml`.
- **Observability:** Actuator endpoints `health, info, metrics` exposed per service.
- **Docs:** PlantUML diagrams rendered to PNG; `docs/README.md` exportable to PDF via Pandoc in the Maven `site` lifecycle (separate from `mvn verify`).

## 9. Deployment

- **Local (current):** Podman Compose under `platform/compose/docker-compose.yml` — `bpm-kafka` (9092), `bpm-postgres` (5432), `bpm-conduktor-console` (8085), `bpm-conduktor-postgres`. Topics created via `platform/scripts/create-topics.sh`. DB `building_permits`, user/pass `app`/`app`.
- **Target (planned):** Kubernetes on Google Cloud, region `europe-west6` (Zurich) — GKE, Cloud SQL/PostGIS, Kafka, API deployment, web library integrated into the Studio r2 web app. Diagram: `docs/architecture/kubernetes-google-cloud.png`. Not operated for the MVP.

## 10. Key Decisions (ADR-style)

- **AD-1 Microservices over monolith** — chosen so each stage is an independent, portfolio-ready repo and Kafka is a genuine integration layer; accepted cost is higher initial setup, mitigated by keeping each service minimal and starting them together via `platform`.
- **AD-2 Kafka (KRaft) as the backbone** — permits are naturally events (found / changed / normalized / stored); enables multiple consumers, analytics, alerting, reprocessing, and event history.
- **AD-3 PostGIS as read model** — first-class spatial types/queries (radius, within-boundary, zone intersection) that a plain RDBMS can't answer cleanly.
- **AD-4 JSON event serialization for MVP** — simplest to operate; Avro/Protobuf + schema registry deferred.
- **AD-5 GeoAdmin as MVP geocoder** — Swiss-data-accurate, returns WGS84; address-based (not municipality centroids, which are too coarse for permits).
- **AD-6 Deterministic UUID + `(source, external_id)` upsert** — idempotent persistence without external coordination.
- **AD-7 Ingestor consults the persistence registry for dedup** — pragmatic for MVP; introduces a build/runtime coupling from `ingestor` to `persistence` (tracked as a refactor candidate in `backlog.md`).

## 11. Known Constraints & Risks

- Upstream OGD schema drift; missing/renamed fields.
- Geocoding failures / approximate hits — must be surfaced via `geocodingQuality`, never hidden.
- Local Kafka/Postgres failure handling is minimal (log + restart); retries/health-driven backoff are post-MVP.
- This is a prototype, not an authoritative permit register.
