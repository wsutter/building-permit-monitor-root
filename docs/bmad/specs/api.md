# Module Spec — `api`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Spring Boot microservice
> Read model over PostGIS. Maps to PRD Epic E. (No `api/README.md` exists yet — this spec is the canonical description.)

## Purpose

Expose stored building-permit data to the Studio r2 web app and external clients through a REST API. `api` is a pure read model over the PostgreSQL/PostGIS database — it has no Kafka dependency and does not participate in the event pipeline.

## Responsibilities

- Query the `building_permits` table.
- Apply optional attribute filters with parameterized SQL.
- Return DTOs (not entities), capped and stably ordered.

## Behavior (current source)

- `BuildingPermitController` (`@RestController`) exposes `GET /api/building-permits` with optional `@RequestParam municipality` and `category`, delegating to `BuildingPermitQueryService`.
- `BuildingPermitQueryService` delegates to `BuildingPermitQueryRepository`.
- `BuildingPermitQueryRepository` uses **`NamedParameterJdbcTemplate`**: builds `SELECT id, title, description, category, status, municipality, published_date, address, latitude, longitude FROM building_permits WHERE 1=1`, appends `AND municipality = :municipality` / `AND category = :category` only when provided (bind parameters — no string interpolation), then `ORDER BY published_date DESC NULLS LAST LIMIT 500`. Rows map to `BuildingPermitDto` via a private `RowMapper`.

## Data Contract

`BuildingPermitDto(UUID id, String title, String description, String category, String status, String municipality, LocalDate publishedDate, String address, Double latitude, Double longitude)`. Note: `geom` and `raw_payload` are intentionally not exposed; coordinates are surfaced as plain `latitude`/`longitude` for map clients (Leaflet `[lat, lon]`).

## Configuration (`application.yml`)

- Datasource: PostgreSQL `building_permits` (`app`/`app`). No Kafka, no Flyway (the schema is owned by `persistence`).
- Actuator: `health, info, metrics`.

## Inputs / Outputs

- **In:** HTTP `GET /api/building-permits?municipality=&category=`.
- **Reads:** `building_permits` (PostGIS) — populated by the `persistence` service.
- **Out:** `List<BuildingPermitDto>` (JSON), newest first, ≤ 500 rows.

## API Reference

| Method | Path | Query params | Returns |
|--------|------|--------------|---------|
| GET | `/api/building-permits` | `municipality` (opt), `category` (opt) | `BuildingPermitDto[]`, `published_date DESC NULLS LAST`, `LIMIT 500` |

Examples:
```bash
curl http://localhost:8080/api/building-permits
curl "http://localhost:8080/api/building-permits?municipality=Thalwil"
curl "http://localhost:8080/api/building-permits?category=RENOVATION"
```

## Acceptance Criteria

- **AC-1:** *Given* stored permits, *when* `GET /api/building-permits` is called with no filters, *then* up to 500 permits are returned ordered by `published_date` descending (nulls last).
- **AC-2:** *Given* `?municipality=Thalwil`, *when* called, *then* only Thalwil permits are returned and the filter is applied via a bind parameter (not concatenated SQL).
- **AC-3:** *Given* both filters, *when* called, *then* results satisfy both conditions.
- **AC-4:** *Given* a permit with null coordinates, *when* returned, *then* `latitude`/`longitude` are null (not fabricated).

## Tests (present)

- `BuildingPermitQueryServiceTest` (extend with controller/web-layer and repository tests as filters grow).

## Run

`mvn spring-boot:run -pl api` (requires PostgreSQL with the `persistence` migrations applied and data present).

## Out of Scope / Future

- **Bounding-box** endpoint over `findVisiblePermits` (backlog B-03) and **radius** endpoint over `findWithinRadius` (B-04) — the queries already exist in `persistence`.
- Date-range and free-text filters; pagination beyond the fixed cap.
- Streaming endpoints (SSE / WebFlux); response caching; OpenAPI/Swagger documentation.
