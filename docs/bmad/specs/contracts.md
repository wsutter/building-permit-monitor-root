# Module Spec — `contracts`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Java library (not Spring Boot)
> Source of truth for the event-driven contract between all services.

## Purpose

Single source of truth for everything shared across the platform: event records, Kafka topic and consumer-group constants, domain enums, shared models, and the central Kafka error-handling/serialization configuration. Every other Java module depends on `contracts`.

## Responsibilities

- Define the three pipeline event records (raw / normalized / enriched).
- Define canonical domain enums and shared value types.
- Centralize Kafka topic names, consumer-group ids, and DLQ routing.
- Provide shared Jackson and Kafka configuration.

## Public Surface (current source)

**Events** (`event/`):
- `BuildingPermitRawEvent` — flat Canton-ZH schema (id, publicationNumber, dates, BFS no., municipality, building-contractor / project-framer / delegation attributes, project description, project-location address fields, district/cadastre relations, lastUpdated). Exposes `externalId()` = `id + ":" + publicationNumber`.
- `BuildingPermitNormalizedEvent(permitId, source, externalId, title, description, category, status, municipality, publishedDate, address)`.
- `BuildingPermitEnrichedEvent(...normalized fields..., Double latitude, Double longitude, GeocodingProvider geocodingProvider, GeocodingQuality geocodingQuality)`.

**Models** (`model/`): `BuildingPermitCategory`, `BuildingPermitStatus`, `Coordinates`.

**Geocoding** (`geocoding/`): `GeocodingProvider` (`GEO_ADMIN`), `GeocodingQuality` (`ADDRESS, PARCEL, MUNICIPALITY, NOT_FOUND`), `GeoAdminQueryParameters`.

**Topics** (`topic/KafkaTopics`): `RAW`, `NORMALIZED`, `ENRICHED`, `RAW_DLQ`, `NORMALIZED_DLQ`, `ENRICHED_DLQ` (= `building-permit.*[.dlq]`).

**Groups** (`group/KafkaGroupIDs`): `NORMALIZER`, `ENRICHER`, `PERSISTENCE`.

**Config** (`config/`): `KafkaConfig`, `JacksonConfig`, and the central DLQ error handler (`KafkaDlqConfiguration` per the architecture) — `DefaultErrorHandler` + `DeadLetterPublishingRecoverer`, `FixedBackOff(1000ms, 3)`, mapping each source topic to its `.dlq`.

## Contracts & Invariants

- Topic names and group ids exist **only** here; services reference the constants.
- Event records are immutable Java records; evolve additively (JSON serialization tolerates new optional fields).
- Enums always include `UNKNOWN` / `NOT_FOUND` for undecidable inputs.
- `externalId` is the stable business key; `permitId` keys normalized/enriched events.

## Dependencies

- Java 25, Jackson (annotations + databind), Spring Kafka & Spring context (for the shared config beans). No database, no web.
- Depended on by: `ingestor`, `normalizer`, `enricher`, `persistence`, `api`.

## Build & Test

- Built/installed first: `mvn -pl contracts install`.
- Tests present: `KafkaTopicsTest`, `BuildingPermitEventTest`. Add coverage when evolving event shapes.

## Acceptance Criteria

- **AC-1:** *Given* any service, *when* it publishes/consumes, *then* it uses `KafkaTopics`/`KafkaGroupIDs` constants (no string literals).
- **AC-2:** *Given* a consumer importing `KafkaDlqConfiguration`, *when* a record fails 3 retries, *then* it is routed to the `.dlq` matching its source topic.
- **AC-3:** *Given* a normalized/enriched event serialized to JSON, *when* deserialized by a downstream consumer trusting `ch.studior2.buildingpermitmonitor.*`, *then* it round-trips without loss.

## Out of Scope / Future

- Avro/Protobuf schemas + schema registry (MVP is JSON).
- JSON Schema example fixtures (`examples/*.json`) per the vision doc — add as contract tests mature.
