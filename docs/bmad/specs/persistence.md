# Module Spec — `persistence`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Spring Boot microservice
> Final pipeline stage. Maps to PRD Epic D (and supports Epic A dedup).

## Purpose

Consume enriched events and store them idempotently in PostgreSQL/PostGIS, manage the schema via Flyway, and provide the raw-event registry used by the ingestor for duplicate detection.

## Responsibilities

- Consume enriched events and upsert them into `building_permits`.
- Build and store PostGIS geometry from coordinates.
- Own the database schema (Flyway).
- Maintain the raw-event registry.
- Support spatial queries (radius, bounding box).

## Behavior (current source)

- `BuildingPermitPersistenceConsumer` (`@KafkaListener` on `KafkaTopics.ENRICHED`, group `persistence`) delegates to `BuildingPermitPersistenceService.upsert(event)`.
- `upsert` is `@Transactional`: find-or-create by `(source, externalId)`; set `id = UUID.nameUUIDFromBytes(permitId)`; copy all fields; set `geom = pointFactory.create(latitude, longitude)`; set `rawPayload = objectMapper.writeValueAsString(event)`; `repository.save(entity)`.
- `PointFactory` builds a JTS `Point` (SRID 4326) only when both coordinates are present (null geom otherwise).
- `BuildingPermitRepository` (Spring Data JPA) provides `findBySourceAndExternalId`, plus native PostGIS queries: `findWithinRadius(point, radiusMeters)` via `ST_DWithin(geom::geography, :point::geography, :radiusMeters)` and `findVisiblePermits(minLon, minLat, maxLon, maxLat)` via `geom && ST_MakeEnvelope(..., 4326)`.
- Raw-event registry: `BuildingPermitRawEventRegistry` (interface, `api/`) implemented by `JpaBuildingPermitRawEventRegistry` over `BuildingPermitRawEventRegistryRepository` / `BuildingPermitRawEventRegistryEntry`. `registerIfNew(...)` records the external id and reports whether it was new.

## Schema (Flyway migrations)

- `V1__create_building_permit_raw_event_registry.sql` — `building_permit_raw_event_registry(external_id PK, first_seen_at)` + unique index.
- `V2__create_extension_postgis.sql` — `CREATE EXTENSION postgis`; `building_permits(id UUID PK, source, external_id, title, description, category, status, municipality, published_date, address, latitude, longitude, geocoding_provider, geocoding_quality, geom GEOMETRY(Point,4326), raw_payload JSONB, created_at, updated_at, UNIQUE(source, external_id))`; indexes on `(source, external_id)`, `municipality`, `published_date`, and GIST on `geom`.

## Entity Mapping

- `BuildingPermitEntity` → table `building_permits`; `geom` via `@JdbcTypeCode(SqlTypes.GEOMETRY)`; `rawPayload` via `SqlTypes.JSON`; `geocodingProvider`/`geocodingQuality` as `@Enumerated(STRING)`.

## Configuration (`application.yml`)

- Datasource PostgreSQL `building_permits` (`app`/`app`), `org.hibernate.dialect.PostgreSQLDialect`, `ddl-auto: validate`, `open-in-view: false`.
- `flyway.enabled: true`, `locations: classpath:db/migration`.
- Imports the central `KafkaDlqConfiguration`. Actuator `health, info, metrics`.

## Inputs / Outputs

- **In:** `building-permit.enriched` (group `persistence`).
- **Out:** rows in `building_permits` (PostGIS).
- **Error:** `building-permit.enriched.dlq`.
- **Provides:** `BuildingPermitRawEventRegistry` (consumed by `ingestor`); spatial query methods (foundation for `api`).

## Acceptance Criteria

- **AC-1:** *Given* an enriched event, *when* persisted, *then* a row keyed by `(source, external_id)` exists with `id = nameUUIDFromBytes(permitId)`.
- **AC-2:** *Given* a re-delivered event for the same permit, *when* persisted, *then* the existing row is updated (no duplicate).
- **AC-3:** *Given* both coordinates present, *when* persisted, *then* `geom` is a non-null `Point` of SRID 4326 built as `(longitude, latitude)`; if either is null, `geom` is null.
- **AC-4:** *Given* persisted permits, *when* `findWithinRadius` / `findVisiblePermits` run, *then* only spatially matching rows are returned.

## Tests (present)

- `BuildingPermitPersistenceConsumerTest`, `BuildingPermitPersistenceServiceTest`, `BuildingPermitRepositoryTest` (Testcontainers `postgis/postgis:17-3.5`), `PointFactoryTest`, `JpaBuildingPermitRawEventRegistryTest`.

## Run

`mvn -pl persistence flyway:migrate` then `mvn spring-boot:run -pl persistence`.

## Out of Scope / Future

- `updated_at` trigger / explicit bump on upsert; `created_at`/`updated_at` lifecycle handling; statistics tables; read-replica concerns.
