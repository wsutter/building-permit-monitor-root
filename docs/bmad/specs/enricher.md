# Module Spec — `enricher`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Spring Boot microservice
> Maps to PRD Epic C.

## Purpose

Enrich normalized permits with geographic coordinates obtained from the Swiss GeoAdmin geocoding service.

## Responsibilities

- Consume normalized events.
- Geocode the address (with municipality as context) to WGS84 coordinates.
- Attach geocoding provider and quality metadata.
- Publish enriched events; route failures to the normalized DLQ.

## Behavior (current source)

- `BuildingPermitEnricher` (`@KafkaListener` on `KafkaTopics.NORMALIZED`, group `enricher`) calls the `GeocodingClient` and publishes a `BuildingPermitEnrichedEvent` to `KafkaTopics.ENRICHED` (key `permitId`).
- `GeoAdminGeocodingClient` (Spring WebFlux `WebClient`/Reactor) queries the GeoAdmin Search API and maps responses via `GeoAdminSearchResponse` / `GeoAdminSearchResult` / `GeoAdminSearchAttributes`.
- Coordinates returned as WGS84 (EPSG:4326) `latitude` / `longitude`; `geocodingProvider = GEO_ADMIN`; `geocodingQuality` ∈ `{ADDRESS, PARCEL, MUNICIPALITY, NOT_FOUND}`.

## Geocoding Rules

- **Fallback strategy:** full address (street, number, ZIP, town) → reduced address (street, ZIP, town) → town/municipality → no marker.
- **Never fabricate** coordinates: if nothing reliable resolves, emit null coordinates with `geocodingQuality = NOT_FOUND`.
- Municipality centroids are at most an optional, clearly-marked approximate fallback — not mixed with address-precise hits.
- WGS84 throughout (`spatial-reference: 4326`) so no coordinate transform is needed downstream.

## Configuration (`application.yml`)

- Kafka consumer group `enricher` + producer (Jackson JSON).
- `building-permit.geocoding`: `provider: geo-admin`, `base-url: https://api3.geo.admin.ch`, `search-path: /rest/services/api/SearchServer`, `timeout: 5s`, `type: locations`, `origins: address,parcel`, `spatial-reference: 4326`, `limit: 1`.
- `GeocodingProperties` / `GeocodingConfiguration` bind this config; a `WebClient.Builder` bean is provided (requires `spring-boot-starter-webflux`).
- Imports the central `KafkaDlqConfiguration`.

## Inputs / Outputs

- **In:** `building-permit.normalized` (group `enricher`).
- **Out:** `building-permit.enriched` (key = `permitId`).
- **Error:** `building-permit.normalized.dlq`.
- **External:** GeoAdmin Search API (HTTP).

## Acceptance Criteria

- **AC-1:** *Given* a normalized event with a resolvable address, *when* enriched, *then* it carries WGS84 lat/lon, `GEO_ADMIN`, and a non-`NOT_FOUND` quality.
- **AC-2:** *Given* an unresolvable address, *when* enriched, *then* coordinates are null and quality is `NOT_FOUND` (no fabricated point).
- **AC-3:** *Given* a GeoAdmin call failure that exhausts retries, *when* processed, *then* the message lands on `building-permit.normalized.dlq`.

## Tests (present)

- `GeoAdminGeocodingClientTest`, `BuildingPermitEnricherTest`.

## Run

`mvn spring-boot:run -pl enricher` (needs network access to GeoAdmin).

## Out of Scope / Future

- Additional enrichment stages: zoning, noise, flood, public-transport proximity (post-MVP — see `backlog.md`).
- Additional geocoding providers / quality tiers (`STREET`, etc.).
